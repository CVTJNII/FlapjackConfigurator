#!/usr/bin/ruby
require 'deep_clone'

# Walk though the entities and build the map of entities to contacts
# Built as a class for future proofing and because this is expected to
# be an expensive operation: so instantiate it once and pass it around.
class EntityMapper
  attr_accessor :entity_map

  def initialize(config_obj, diner)
    @entity_map = {}.tap { |em| config_obj.contact_ids.each { |cn| em[cn.to_sym] = [] } }

    # Walk the entities and compare each individually so that the whitelisting/blacklisting can be easily enforced
    # This probably will need some optimization
    diner.entities.each do |entity|
      config_obj.contact_ids.each do |contact_name|
        match_id = _check_entity(entity, config_obj.contact_config(contact_name))
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

  def initialize(my_id, current_config, getter_method, create_method, update_method, delete_method, logger, log_name)
    @config = {}
    @logger = logger
    @log_name = log_name # A user friendly name for log entries

    @getter_method = getter_method
    @create_method = create_method
    @update_method = update_method
    @delete_method = delete_method

    # Load the object from the API if needed
    # The current config from Flapjack is passable to avoid polling the API for each individual contact
    if my_id
      @config[:id] = my_id
      current_config = _load_from_api(my_id) unless current_config
    end

    if current_config
      @config.merge! current_config if current_config
      @obj_exists = true
    else
      @obj_exists = false
    end
  end

  # Load the config from the API
  def _load_from_api(my_id)
    api_data = @getter_method.call(my_id)
    return nil if api_data.nil?

    fail "Unexpected number of responses for #{@log_name} #{my_id}" unless api_data.length == 1
    return api_data[0]
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

    @logger.info("Updating #{@log_name} #{id} with changes #{change_list}")
    fail "Failed to update #{id}" unless @update_method.call(id, change_list)
    _reload_config
  end

  # Delete the object
  def delete
    fail("Object #{id} doesn't exist") unless @obj_exists
    @logger.info("Deleting #{@log_name} #{id}")
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
    @logger.info("Creating #{@log_name} #{id} with config #{@config}")
    fail "Failed to create #{@log_name} #{id}" unless @create_method.call(contact_id, @config)
    _reload_config
  end

  def _filter_config(config)
    filtered_config = config.select { |k, _| @allowed_config_keys.include? k.to_sym }
    @logger.debug("#{@log_name} #{id}: Config keys filtered out: #{config.keys - filtered_config.keys}")
    @logger.debug("#{@log_name} #{id}: Allowed keys: #{@allowed_config_keys}")
    return filtered_config
  end

  # Update the media from a config hash of updated values
  def update(config)
    _update(_filter_config(config))
  end
end

# Class representing Flapjack media
class FlapjackMedia < FlapjackSubObjectBase
  def initialize(current_config, diner, logger)
    super(nil, current_config, diner.method(:media), diner.method(:create_contact_media), diner.method(:update_media), diner.method(:delete_media), logger, 'media')
    @allowed_config_keys = [:address, :interval, :rollup_threshold]
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

# Class representing Pagerduty credentials
# In Flapjack 1.x Pagerduty is somewhat duct-taped to the side of the thing and not handled as media.
# However, to make our lives easier, make this class look like FlapjackMedia so that it can be handled like a media entry
class FlapjackPagerduty < FlapjackSubObjectBase
  def initialize(current_config, diner, logger)
    # The contact ID is essentially the pagerduty credentials ID; 1-1
    # Pull the ID from the config.  Contacts is an array but in practice it only appears to ever be single-element.
    conf_id = current_config.nil? ? nil : current_config[:links][:contacts][0]
    super(conf_id, current_config, diner.method(:pagerduty_credentials), diner.method(:create_contact_pagerduty_credentials),
          diner.method(:update_pagerduty_credentials), diner.method(:delete_pagerduty_credentials), logger, 'pagerduty')
    @allowed_config_keys = [:subdomain, :token, :service_key]
  end

  def create(contact_id, config)
    config[:id] = contact_id
    _create(contact_id, _filter_config(config))
  end

  # Type helper to match FlapjackMedia
  def type
    return 'pagerduty'
  end
end

# Class representing notification rules
class FlapjackNotificationRule < FlapjackSubObjectBase
  def initialize(conf_id, current_config, diner, logger)
    super(conf_id, current_config, diner.method(:notification_rules), diner.method(:create_contact_notification_rules), diner.method(:update_notification_rules),
          diner.method(:delete_notification_rules), logger, 'notification rule')
  end

  def create(contact_id, config)
    # Flapjack will let you create a notification rule object with no attributes, but that sets nils whereas
    # the default it creates has empty arrays.
    # Set up a baseline config that matches what Flapjack creates by default
    full_config = {
      tags: [],
      regex_tags: [],
      entities: [],
      regex_entities: [],
      time_restrictions: [],
      warning_media: nil,
      critical_media: nil,
      unknown_media: nil,
      unknown_blackhole: false,
      warning_blackhole: false,
      critical_blackhole: false
    }.merge(config)

    _create(contact_id, full_config)
  end

  def update(config)
    _update(config)
  end
end

# Class representing a Flapjack contact
class FlapjackContact < FlapjackObjectBase
  attr_accessor :media

  def initialize(my_id, current_config, diner, logger, current_media = [], current_notification_rules = [])
    @diner = diner
    @logger = logger
    super(my_id, current_config, diner.method(:contacts), diner.method(:create_contacts), diner.method(:update_contacts), diner.method(:delete_contacts), logger, 'contact')

    # Select our media out from a premade hash of all media built from a single API call
    @media = current_media.select { |m| m.config[:links][:contacts].include? id }

    # Select notification rules the same way.
    @notification_rules = current_notification_rules.select { |m| m.config[:links][:contacts].include? id }
  end

  # Update all the things
  def update(config_obj)
    update_attributes(config_obj)
    update_entities(config_obj)
    update_media(config_obj)
    update_notification_rules(config_obj)
  end

  # Define our own _create as it doesn't use an ID
  def _create(config)
    fail("Object #{id} exists") if @obj_exists
    # AFAIK there is not an easy way to convert hash keys to symbols outside of Rails
    config.each { |k, v| @config[k.to_sym] = v }
    @logger.info("Creating contact #{id} with config #{@config}")
    fail "Failed to create contact #{id}" unless @create_method.call([@config])
    _reload_config

    # Creating an entity auto generates notification rules
    # Regenerate the notification rules
    @notification_rules = []
    @config[:links][:notification_rules].each do |nr_id|
      @notification_rules << FlapjackNotificationRule.new(nr_id, nil, @diner, @logger)
    end
  end

  # Update attributes from the config, creating the contact if needed
  # (Chef definition of "update")
  # Does not handle entites or notifications
  def update_attributes(config_obj)
    @logger.debug("Updating attributes for contact #{id}")
    if @obj_exists
      _update(config_obj.contact_config(id)['details'])
    else
      _create(config_obj.contact_config(id)['details'])
    end
  end

  # Update entities for the contact, creating or removing as needed
  def update_entities(config_obj)
    fail("Contact #{id} doesn't exist yet") unless @obj_exists
    @logger.debug("Updating entities for contact #{id}")

    wanted_entities = config_obj.entity_map.entities_for_contact(id)
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
  def update_media(config_obj)
    @logger.debug("Updating media for contact #{id}")
    media_config = config_obj.media(id)

    media_config_types = media_config.keys
    @media.each do |media_obj|
      if media_config_types.include? media_obj.type
        media_obj.update(media_config[media_obj.type])

        # Delete the ID from the type array
        # This will result in media_config_types being a list of types that need to be created at the end of the loop
        media_config_types.delete(media_obj.type)
      else
        @media.delete(media_obj)
        media_obj.delete
      end
    end

    media_config_types.each do |type|
      # Pagerduty special case again
      # TODO: Push this back up so that the if isn't done here
      if type == 'pagerduty'
        media_obj = FlapjackPagerduty.new(nil, @diner, @logger)
        media_obj.create(id, media_config[type])
      else
        media_obj = FlapjackMedia.new(nil, @diner, @logger)
        media_obj.create(id, type, media_config[type])
      end
      @media << media_obj
    end
  end

  def update_notification_rules(config_obj)
    @logger.debug("Updating notification rules for contact #{id}")
    nr_config = config_obj.notification_rules(id)
    nr_config_ids = nr_config.keys

    @notification_rules.each do |nr_obj|
      if nr_config_ids.include? nr_obj.id
        nr_obj.update(nr_config[nr_obj.id])

        # Delete the ID from the type array
        # This will result in nr_config_ids being a list of types that need to be created at the end of the loop
        nr_config_ids.delete(nr_obj.id)
      else
        @notification_rules.delete(nr_obj)
        nr_obj.delete
      end
    end

    nr_config_ids.each do |nr_id|
      nr_obj = FlapjackNotificationRule.new(nr_id, nil, @diner, @logger)
      nr_obj.create(id, nr_config[nr_id])
      @notification_rules << (nr_obj)
    end
  end
end

# User Configuration: Class representing the desired configuration as passed into the utility
class UserConfiguration
  attr_accessor :config, :entity_map

  def initialize(config, diner, logger)
    @config = config
    @logger = logger
    @media_config = {}

    _sanity_check

    @entity_map = EntityMapper.new(self, diner)
  end

  def _sanity_check
    # Check that required keys are present
    fail('Config missing contacts block') unless @config.key? 'contacts'
    @config['contacts'].each do |contact_id, contact_val|
      %w(details notification_media notification_rules).each do |contact_opt|
        fail("#{contact_id} contact config missing #{contact_opt} block") unless contact_val.key? contact_opt
      end
    end
  end

  def contact_ids
    @config['contacts'].keys
  end

  def contact_config(contact_id)
    return nil unless @config['contacts'].key? contact_id

    # Merge in defaults for keys which may be omitted
    return {
      entites: { exact: [], regex: [] },
      entites_blacklist: { exact: [], regex: [] }
    }.merge(@config['contacts'][contact_id])
  end

  def baseline_config
    if @config.key? 'baseline_options'
      return @config['baseline_options']
    else
      return {}
    end
  end

  def _complete_config_merge(contact_id, config_key)
    contact_setting = contact_config(contact_id)[config_key]
    fail("Missing #{config_key} settings for contact #{contact_id}") if contact_setting.nil?

    merged_config = baseline_config.key?(config_key) ? DeepClone.clone(baseline_config[config_key]) : {}
    contact_defaults = contact_setting.key?('defaults') ? contact_setting['defaults'] : {}

    (contact_setting.keys - %w(defaults)).each do |key|
      # Merge merge merge!
      if merged_config.key? key
        merged_config[key].merge!(contact_defaults.merge(contact_setting[key]))
      else
        merged_config[key] = contact_defaults.merge(contact_setting[key])
      end
    end

    @logger.debug("#{contact_id} #{config_key} complete config: #{merged_config}")
    return merged_config
  end

  def media(contact_id)
    if @media_config[contact_id].nil?
      @media_config[contact_id] = _complete_config_merge(contact_id, 'notification_media')
    end
    return @media_config[contact_id]
  end

  def notification_rules(contact_id)
    notification_rules = _complete_config_merge(contact_id, 'notification_rules')

    # Double check that the defined rules call for media which exists
    notification_rules.each do |nr_id, nr_val|
      %w(warning_media critical_media unknown_media).each do |alert_type|
        next unless nr_val.key? alert_type
        nr_val[alert_type].each do |alert_media|
          unless media(contact_id).keys.include? alert_media
            @logger.warn("Notification rule #{nr_id} for contact #{contact_id} calls for media #{alert_media} in #{alert_type} but #{alert_media} for #{contact_id} isn't defined")
          end
        end
      end
    end

    # The notification rules need to have unique IDs contianing the contact id
    return {}.tap { |rv| notification_rules.each { |nr_id, nr_val| rv["#{contact_id}_#{nr_id}"] = nr_val } }
  end
end

# Class representing the overall Flapjack config
class FlapjackConfig
  attr_accessor :config_obj, :contacts

  def initialize(config, diner, logger)
    @config_obj = UserConfiguration.new(config, diner, logger)
    @diner  = diner
    @logger = logger

    # Media will be tied in via the contacts, however pregenerate objects off a single API call for speed.
    media = @diner.media.map { |api_media| FlapjackMedia.new(api_media, @diner, logger) }
    # Also add PagerDuty creds into media.  PD creds are handled separately by the API but can be grouped thanks to our class handling.
    media += @diner.pagerduty_credentials.map { |api_pd| FlapjackPagerduty.new(api_pd, @diner, logger) }

    # Prebuild notification rules for the same reason
    notification_rules = @diner.notification_rules.map { |api_nr| FlapjackNotificationRule.new(nil, api_nr, @diner, logger) }

    @contacts = {}.tap { |ce| @diner.contacts.map { |api_contact| ce[api_contact[:id]] = FlapjackContact.new(nil, api_contact, @diner, logger, media, notification_rules) } }
  end

  # Loop over the contacts and call update/create/remove methods as needed
  # Builds the @contacts hash
  def update_contacts
    config_contact_ids = @config_obj.contact_ids

    @contacts.each do |id, contact_obj|
      if config_contact_ids.include? id
        contact_obj.update(@config_obj)

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
      contact_obj = FlapjackContact.new(new_id, nil, @diner, @logger)
      contact_obj.update(@config_obj)
      @contacts[new_id] = contact_obj
    end
  end
end
