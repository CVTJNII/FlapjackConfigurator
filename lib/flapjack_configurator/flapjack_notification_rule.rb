#!/usr/bin/env ruby

require_relative 'flapjack_sub_object_base.rb'

module FlapjackConfigurator
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
      return _update(config)
    end
  end
end
