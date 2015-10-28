#!/usr/bin/env ruby
require 'deep_clone'

module FlapjackConfigurator
# Walk though the entities and build the map of entities to contacts
# Built as a class for future proofing and because this is expected to
# be an expensive operation: so instantiate it once and pass it around.
  class EntityMapper
    attr_accessor :entity_map
    
    def initialize(config_obj, diner)
      @entity_map = {}.tap { |em| config_obj.contact_ids.each { |cn| em[cn.to_sym] = [] } }
      
      # Walk the entities and compare each individually so that the whitelisting/blacklisting can be easily enforced
      # This probably will need some optimization
      diner.entities.each do |entity|
        config_obj.contact_ids.each do |contact_name|
          match_id = _check_entity(entity, config_obj.contact_config(contact_name))
          @entity_map[contact_name.to_sym].push(match_id) if match_id
        end
      end
      
      return @entity_map
    end
    
    # Check if entity should be included in contact
    # Helper for _build_entity_map
    # Returns the entity ID on match or nil on no match
    def _check_entity(entity, contact)
      # Priority 1: Exact Entries
      return entity[:id] if contact['entities']['exact'].include? entity[:name]
      
      # Priority 2: Exact blacklist
      return nil if contact['entities_blacklist']['exact'].include? entity[:name]
      
      # Priority 3: Regex blacklist
      contact['entities_blacklist']['regex'].each do |bl_regex|
        return nil if /#{bl_regex}/.match(entity[:name])
      end
      
      # Priority 4: Match regex
      contact['entities']['regex'].each do |m_regex|
        return entity[:id] if /#{m_regex}/.match(entity[:name])
      end
    end
    
    # Return the entities for the given contact
    # Returns a clone so the returned object is modifyable
    def entities_for_contact(id)
      fail("ID #{id} not in entity map") unless @entity_map.key? id.to_sym
      return DeepClone.clone @entity_map[id.to_sym]
    end
  end
end
