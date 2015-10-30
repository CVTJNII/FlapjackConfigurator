#!/usr/bin/env ruby

module FlapjackConfigurator
  # Baseline class representing a Flapjack object
  class FlapjackObjectBase
    attr_reader :config, :obj_exists

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
        @config.merge! current_config
        @obj_exists = true
      else
        @obj_exists = false
      end
    end

    # Load the config from the API
    def _load_from_api(my_id)
      api_data = @getter_method.call(my_id)
      return nil unless api_data

      fail "Unexpected number of responses for #{@log_name} #{my_id}" unless api_data.length == 1
      return api_data[0]
    end

    # Simple helper to return the ID
    def id
      return @config[:id]
    end

    def _reload_config
      my_id = id
      api_obj = @getter_method.call(my_id)
      fail "Config reload failed for config ID #{my_id}: not found" unless api_obj
      @config = api_obj[0]
      fail "Config reload failed for config ID #{my_id}: parse error" unless @config
      @obj_exists = true
    end

    # No base create object as the method arguments differ too much.

    # Update the object
    def _update(config)
      fail("Object #{id} doesn't exist") unless @obj_exists
      change_list = {}
      config.each do |k, v|
        k_sym = k.to_sym
        if @config[k_sym] != v
          change_list[k_sym] = v
        end
      end

      return false if change_list.empty?

      @logger.info("Updating #{@log_name} #{id}")
      @logger.debug("#{@log_name} #{id} changes: #{change_list}")
      fail "Failed to update #{id}" unless @update_method.call(id, change_list)
      _reload_config
      return true
    end

    # Delete the object
    def delete
      fail("Object #{id} doesn't exist") unless @obj_exists
      @logger.info("Deleting #{@log_name} #{id}")
      fail "Failed to delete #{id}" unless @delete_method.call(id)
      @obj_exists = false
    end
  end
end
