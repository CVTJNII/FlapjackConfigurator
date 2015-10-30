#!/usr/bin/env ruby

require 'flapjack-diner'
require 'logger'
require 'flapjack_configurator/flapjack_config'
require 'flapjack_configurator/version'

# Flapjack Configuration Module
module FlapjackConfigurator
  # Method to configure flapjack
  def self.configure_flapjack(config, api_base_url = 'http://127.0.0.1:3081', logger = Logger.new(STDOUT), enable_all_entity = true)
    ret_val = false
    Flapjack::Diner.base_uri(api_base_url)

    # The underlying classes treat the Flapjack::Diner module as if it is a class.
    # This was done as it was fairly natural and will allow Flapjack::Diner to be
    # replaced or wrapped very easily in the future.
    config_obj = FlapjackConfig.new(config, Flapjack::Diner, logger)

    if enable_all_entity
      # Ensure the ALL entity is present
      ret_val = true if config_obj.add_all_entity
    end

    # Update the contacts
    # This will update media, PD creds, notification rules, and entity associations
    #   as they're associated to the contact.
    ret_val = true if config_obj.update_contacts

    return ret_val
  end
end
