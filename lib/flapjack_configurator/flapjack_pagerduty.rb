#!/usr/bin/env ruby

require_relative 'flapjack_sub_object_base.rb'

module FlapjackConfigurator
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
end
