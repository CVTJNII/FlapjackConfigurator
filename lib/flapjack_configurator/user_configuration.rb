#!/usr/bin/ruby

require 'deep_clone'
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
end
