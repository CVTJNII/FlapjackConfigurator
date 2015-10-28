#!/usr/bin/env ruby

require_relative 'flapjack_object_base.rb'

module FlapjackConfigurator
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
      return _update(_filter_config(config))
    end
  end
end
