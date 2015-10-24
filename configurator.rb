#!/usr/bin/ruby
require 'deep_clone'

# Walk though the entities and build the map of entities to contacts
# Built as a class for future proofing and because this is expected to
# be an expensive operation: so instantiate it once and pass it around.
class EntityMapper
  attr_accessor :entity_map

  def initialize(config, diner)
    @entity_map = {}.tap { |em| config['contacts'].keys.each { |cn| em[cn.to_sym] = [] } }

    # Walk the entities and compare each individually so that the whitelisting/blacklisting can be easily enforced
    # This probably will need some optimization
    diner.entities.each do |entity|
      config['contacts'].each do |contact_name, contact|
        match_id = _check_entity(entity, contact)
        @entity_map[contact_name.to_sym].push(match_id) if match_id
      end
    end

    return @entity_map
  end

  # Check if entity should be included in contact
  # Helper for _build_entity_map
  # Returns the entity ID on match or nil on no match
  def _check_entity(entity, contact)
    # Priority 1: Exact Entries
    return entity[:id] if contact['entities']['exact'].include? entity[:name]

    # Priority 2: Exact blacklist
    return nil if contact['entities_blacklist']['exact'].include? entity[:name]

    # Priority 3: Regex blacklist
    contact['entities_blacklist']['regex'].each do |bl_regex|
      return nil if /#{bl_regex}/.match(entity[:name])
    end

    # Priority 4: Match regex
    contact['entities']['regex'].each do |m_regex|
      return entity[:id] if /#{m_regex}/.match(entity[:name])
    end
  end

  # Return the entities for the given contact
  # Returns a clone so the returned object is modifyable
  def entities_for_contact(id)
    fail("ID #{id} not in entity map") unless @entity_map.key? id.to_sym
    return DeepClone.clone @entity_map[id.to_sym]
  end
end

# Class representing a Flapjack contact
class FlapjackContact
  attr_accessor :config

  def initialize(id, diner, current_config = nil)
    @config = { id: id }
    @diner = diner

    # Load the object from the API if needed
    # The current config from Flapjack is passable to avoid polling the API for each individual contact
    current_config = diner.contacts(id) unless current_config
    if current_config
      @config.merge! current_config if current_config
      @contact_exists = true
    else
      @contact_exists = false
    end
  end

  def _reload_config
    @config = @diner.contacts(@config[:id])
    fail "Config reload failed for contact ID #{@config[:id]}" if @config.nil?
  end

  # Update attributes from the config, creating the contact if needed
  # (Chef definition of "update")
  # Does not handle entites or notifications
  def update_attributes(contact_config)
    if @contact_exists
      change_list = {}
      contact_config['details'].each do |k, v|
        if @config[k.to_sym] != v
          change_list[k.to_sym] = v
        end
      end

      unless change_list.empty?
        fail "Failed to update #{@config[:id]}" unless @diner.update_contacts(@config[:id], change_list)
        _reload_config
      end
    else
      # AFAIK there is not an easy way to convert hash keys to symbols outside of Rails
      contact_config['details'].each { |k, v| @config[k.to_sym] = v }
      fail "Failed to create #{@config[:id]}" unless @diner.create_contacts([@config])
    end
  end

  # Update entities for the contact, creating or removing as needed
  def update_entities(entity_mapper)
    fail("Contact #{@config[:id]} doesn't exist yet") unless @contact_exists

    wanted_entities = entity_mapper.entities_for_contact(@config[:id])
    current_entities = @config[:links][:entities]

    (wanted_entities - current_entities).each do |entity_id|
      unless @diner.update_contacts(@config[:id], add_entity: entity_id)
        fail("Failed to add entity #{entity_id} to contact #{@config[:id]}")
      end
    end

    (current_entities - wanted_entities).each do |entity_id|
      unless @diner.update_contacts(@config[:id], remove_entity: entity_id)
        fail("Failed to remove entity #{entity_id} from contact #{@config[:id]}")
      end
    end

    _reload_config
  end

  def delete
    fail "Failed to delete #{@config[:id]}" unless @diner.delete_contacts(@config[:id])
    @contact_exists = false
  end
end

# Class representing the overall Flapjack config
class FlapjackConfig
  attr_accessor :config, :contacts

  def initialize(config, diner)
    @config = config
    @diner = diner

    @entity_mapper = EntityMapper.new(@config, @diner)
  end

  # Loop over the contacts and call update/create/remove methods as needed
  # Builds the @contacts hash
  def update_contacts
    current_contacts = @diner.contacts
    config_contact_ids = @config['contacts'].keys

    @contacts = {}

    current_contacts.each do |api_contact|
      contact_obj = FlapjackContact.new(api_contact[:id], @diner, api_contact)

      if config_contact_ids.include? api_contact[:id]
        contact_obj.update_attributes(@config['contacts'][api_contact[:id]])
        @contacts[api_contact[:id]] = contact_obj

        # Delete the ID from the id array
        # This will result in config_contact_ids being a list of IDs that need to be created at the end of the loop
        config_contact_ids.delete(api_contact[:id])
      else
        # Delete contact from Flapjack
        contact_obj.delete
      end
    end

    # Add new contacts to Flapjack
    config_contact_ids.each do |new_id|
      contact_obj = FlapjackContact.new(new_id, @diner)
      contact_obj.update_attributes(@config['contacts'][new_id])
      @contacts[new_id] = contact_obj
    end

    @contacts.each { |_, contact_obj| contact_obj.update_entities(@entity_mapper) }

    @contacts
  end
end
