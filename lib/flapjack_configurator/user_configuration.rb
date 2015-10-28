#!/usr/bin/env ruby

require 'deep_merge'
require_relative 'entity_mapper.rb'

module FlapjackConfigurator
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
        'entities' => { 'exact' => [], 'regex' => [] },
        'entities_blacklist' => { 'exact' => [], 'regex' => [] }
      }.deep_merge(@config['contacts'][contact_id])
    end

    # Return a list of contacts with the default bit set
    # This is pretty entitymapper centric, but it makes more sense here due to current layout.
    def default_contacts
      return @config['contacts'].select { |_, c| c['entities']['default'] }.keys
    end

    def baseline_config
      if @config.key? 'baseline_options'
        return @config['baseline_options']
      else
        return {}
      end
    end

    def _complete_config_merge(contact_id, config_key)
      contact_settings = contact_config(contact_id)[config_key]
      fail("Missing #{config_key} settings for contact #{contact_id}") if contact_settings.nil?

      baseline_opts = baseline_config.key?(config_key) ? baseline_config[config_key] : {}
      contact_defaults = contact_settings.key?('defaults') ? contact_settings['defaults'] : {}

      merged_config = {}
      (contact_settings.keys - %w(defaults)).each do |key|
        # Only merge baseline/defaults if the contact has the setting defined
        # This is to prevent errors from partial configs built from only partial defaults.
        if baseline_opts.key? key
          merged_config[key] = baseline_opts.merge(contact_defaults.merge(contact_settings[key]))
        else
          merged_config[key] = contact_defaults.merge(contact_settings[key])
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
              @logger.warn("Notification rule #{nr_id} for contact #{contact_id} calls for media #{alert_media} in #{alert_type} which isn't defined for #{contact_id}")
            end
          end
        end
      end

      # The notification rules need to have unique IDs contianing the contact id
      return {}.tap { |rv| notification_rules.each { |nr_id, nr_val| rv["#{contact_id}_#{nr_id}"] = nr_val } }
    end
  end
end
