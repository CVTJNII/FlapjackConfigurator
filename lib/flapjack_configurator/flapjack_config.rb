#!/usr/bin/env ruby

require_relative 'user_configuration.rb'
require_relative 'flapjack_media.rb'
require_relative 'flapjack_pagerduty.rb'
require_relative 'flapjack_notification_rule.rb'
require_relative 'flapjack_contact.rb'

module FlapjackConfigurator
  # Class representing the overall Flapjack config
  class FlapjackConfig
    attr_reader :config_obj, :contacts

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
      ret_val = false

      # Iterate over a list of keys to avoid the iterator being impacted by deletes
      @contacts.keys.each do |id|
        if config_contact_ids.include? id
          ret_val = true if @contacts[id].update(@config_obj)

          # Delete the ID from the id array
          # This will result in config_contact_ids being a list of IDs that need to be created at the end of the loop
          config_contact_ids.delete(id)
        else
          # Delete contact from Flapjack
          @contacts[id].delete
          @contacts.delete(id)
          ret_val = true
        end
      end

      # Add new contacts to Flapjack
      config_contact_ids.each do |new_id|
        contact_obj = FlapjackContact.new(new_id, nil, @diner, @logger)
        contact_obj.update(@config_obj)
        @contacts[new_id] = contact_obj
      end

      # Return true if changes made
      return ret_val || config_contact_ids.length > 0
    end

    # Ensure the ALL entity is present
    # http://flapjack.io/docs/1.0/usage/Howto-Dynamic-Entity-Contact-Linking/
    def add_all_entity
      return false if @diner.entities('ALL')
      @logger.info('Creating the ALL magic entity')
      fail('Failed to create ALL entity') unless @diner.create_entities(id: 'ALL', name: 'ALL')
      return true
    end
  end
end
