#!/usr/bin/env ruby

require 'flapjack-diner'
require 'logger'
require 'flapjack_configurator/flapjack_config'

module FlapjackConfigurator
  def self.configure_flapjack(config, api_base_url = 'http://127.0.0.1:3081', logger = nil)
    Flapjack::Diner.base_uri('http://127.0.0.1:3081')
    unless logger
      logger = Logger.new(STDOUT)
      logger.level = Logger::INFO
    end

    config_obj = FlapjackConfig.new(config, Flapjack::Diner, logger)

    # Update the contacts
    # This will update media, PD creds, notification rules, and entity associations
    #   as they're associated to the contact.
    return config_obj.update_contacts
  end
end
