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

# Baseline class representing a Flapjack object
class FlapjackObjectBase
  attr_accessor :config

  def initialize(id, current_config, getter_method, create_method, update_method, delete_method)
    @config = {}

    @getter_method = getter_method
    @create_method = create_method
    @update_method = update_method
    @delete_method = delete_method

    # Load the object from the API if needed
    # The current config from Flapjack is passable to avoid polling the API for each individual contact
    if id
      @config[:id] = id
      current_config = @getter_method.call(id) unless current_config
    end

    if current_config
      @config.merge! current_config if current_config
      @obj_exists = true
    else
      @obj_exists = false
    end
  end

  # Simple helper to return the ID
  def id
    return @config[:id]
  end

  def _reload_config
    @config = @getter_method.call(id)[0]
    @obj_exists = true
    fail "Config reload failed for config ID #{id}" if @config.nil?
  end

  # No base create object as the method arguments differ too much.

  # Update the object
  def _update(config)
    fail("Object #{id} doesn't exist") unless @obj_exists
    change_list = {}
    config.each do |k, v|
      if @config[k.to_sym] != v
        change_list[k.to_sym] = v
      end
    end

    return if change_list.empty?

    fail "Failed to update #{id}" unless @update_method.call(id, change_list)
    _reload_config
  end

  # Delete the object
  def delete
    fail("Object #{id} doesn't exist") unless @obj_exists
    fail "Failed to delete #{id}" unless @delete_method.call(id)
    @obj_exists = false
  end
end

# Class representing a Flapjack sub-object (media, pagerduty creds, etc...)
class FlapjackSubObjectBase < FlapjackObjectBase
  # Create the object
  def _create(contact_id, config)
    fail("Object #{id} exists") if @obj_exists
    # AFAIK there is not an easy way to convert hash keys to symbols outside of Rails
    config.each { |k, v| @config[k.to_sym] = v }
    fail "Failed to create #{id}" unless @create_method.call(contact_id, @config)
    _reload_config
  end
end

# Class representing Flapjack media
class FlapjackMedia < FlapjackSubObjectBase
  def initialize(current_config, diner)
    super(nil, current_config, diner.method(:media), diner.method(:create_contact_media), diner.method(:update_media), diner.method(:delete_media))
  end

  def _filter_config(config)
    return config.select { |k, _| [:address, :interval, :rollup_threshold].include? k.to_sym }
  end

  # Update the media from a config hash of updated values (:address, :interval, :rollup_threshold)
  def update(config)
    _update(_filter_config(config))
  end

  # Create a new entry
  def create(contact_id, type, config)
    _create(contact_id, _filter_config(config).merge(type: type))
  end

  # Helper to return the type
  def type
    return @config[:type]
  end
end

# Class representing a Flapjack contact
class FlapjackContact < FlapjackObjectBase
  def initialize(id, current_config, diner, current_media = {})
    @diner = diner
    super(id, current_config, diner.method(:contacts), diner.method(:create_contacts), diner.method(:update_contacts), diner.method(:delete_contacts))

    # Select our media out from a premade hash of all media built from a single API call
    @media = current_media.select { |_, m| m.config[:links][:contacts].include? 'DevOpsTest' }
  end

  # Update all the things
  def update(contact_config, entity_mapper)
    update_attributes(contact_config)
    update_entities(entity_mapper)
    update_media(contact_config)
  end

  # Define our own _create as it doesn't use an ID
  def _create(config)
    fail("Object #{id} exists") if @obj_exists
    # AFAIK there is not an easy way to convert hash keys to symbols outside of Rails
    config.each { |k, v| @config[k.to_sym] = v }
    fail "Failed to create #{id}" unless @create_method.call([@config])
    _reload_config
  end

  # Update attributes from the config, creating the contact if needed
  # (Chef definition of "update")
  # Does not handle entites or notifications
  def update_attributes(contact_config)
    if @obj_exists
      _update(contact_config['details'])
    else
      _create(contact_config['details'])
    end
  end

  # Update entities for the contact, creating or removing as needed
  def update_entities(entity_mapper)
    fail("Contact #{id} doesn't exist yet") unless @obj_exists

    wanted_entities = entity_mapper.entities_for_contact(id)
    current_entities = @config[:links][:entities]

    (wanted_entities - current_entities).each do |entity_id|
      unless @diner.update_contacts(id, add_entity: entity_id)
        fail("Failed to add entity #{entity_id} to contact #{id}")
      end
    end

    (current_entities - wanted_entities).each do |entity_id|
      unless @diner.update_contacts(id, remove_entity: entity_id)
        fail("Failed to remove entity #{entity_id} from contact #{id}")
      end
    end

    _reload_config
  end

  # Update the media for the contact
  def update_media(contact_config)
    # Pagerduty is somewhat bolted on in 1.x aso it needs to be handled independently
    config_media_types = (contact_config['notifications'].keys - %w(defaults pagerduty))

    @media.each do |media_id, media_obj|
      if config_media_types.include? media_obj.type
        media_obj.update(contact_config['notifications']['defaults'].merge(contact_config['notifications'][media_obj.type]))

        # Delete the ID from the type array
        # This will result in config_media_types being a list of types that need to be created at the end of the loop
        config_media_types.delete(media_obj.type)
      else
        media_obj.delete
        @media.delete(media_id)
      end
    end

    config_media_types.each do |type|
      media_obj = FlapjackMedia.new(nil, @diner)
      media_obj.create(id, type, contact_config['notifications']['defaults'].merge(contact_config['notifications'][type]))
      @media[media_obj.id] = media_obj
    end
  end
end

# Class representing the overall Flapjack config
class FlapjackConfig
  attr_accessor :config, :contacts

  def initialize(config, diner)
    @config = config
    @diner = diner

    @entity_mapper = EntityMapper.new(@config, @diner)

    # Media will be tied in via the contacts, however pregenerate objects off a single API call for speed.
    media = {}.tap { |me| @diner.media.map { |api_media| me[api_media[:id]] = FlapjackMedia.new(api_media, @diner) } }

    @contacts = {}.tap { |ce| @diner.contacts.map { |api_contact| ce[api_contact[:id]] = FlapjackContact.new(nil, api_contact, @diner, media) } }
  end

  # Loop over the contacts and call update/create/remove methods as needed
  # Builds the @contacts hash
  def update_contacts
    config_contact_ids = @config['contacts'].keys

    @contacts.each do |id, contact_obj|
      if config_contact_ids.include? id
        contact_obj.update(@config['contacts'][id], @entity_mapper)

        # Delete the ID from the id array
        # This will result in config_contact_ids being a list of IDs that need to be created at the end of the loop
        config_contact_ids.delete(id)
      else
        # Delete contact from Flapjack
        contact_obj.delete
        @contacts.delete(id)
      end
    end

    # Add new contacts to Flapjack
    config_contact_ids.each do |new_id|
      contact_obj = FlapjackContact.new(new_id, nil, @diner)
      contact_obj.update(@config['contacts'][new_id], @entity_mapper)
      @contacts[new_id] = contact_obj
    end

    return @contacts
  end
end
