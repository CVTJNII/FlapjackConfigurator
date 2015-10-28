#!/usr/bin/env ruby

require_relative 'flapjack_sub_object_base.rb'

module FlapjackConfigurator
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
end
