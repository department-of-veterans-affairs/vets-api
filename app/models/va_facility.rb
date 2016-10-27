# frozen_string_literal: true
require_dependency 'facilities/async_client'
require_dependency 'facilities/multi_client'

class VAFacility < ActiveModelSerializers::Model
  attr_accessor :unique_id, :name, :facility_type, :classification, :website,
                :lat, :long, :address, :phone, :hours, :services

  HEALTH = 'health'
  CEMETERY = 'cemetery'
  BENEFITS = 'benefits'
  VHA = 'vha'
  VBA = 'vba'
  NCA = 'nca'

  TYPES = [HEALTH, CEMETERY, BENEFITS].freeze
  ID_PREFIXES = {
    VHA => HEALTH,
    NCA => CEMETERY,
    VBA => BENEFITS
  }.freeze

  def self.query(bbox:, type:, services:)
    query_types = type.nil? ? TYPES : [type]
    requests = query_types.map { |t| client_adapter(t).query(bbox, services) }
    mc = Facilities::MultiClient.new    
    responses = mc.run(requests)
    query_types.zip(responses).each_with_object([]) do |tr, facilities|
      adapter = client_adapter(tr.first)
      tr.second&.each do |record|
        facilities << adapter.class.from_gis(record)
      end
    end
  end

  def self.find_by(id:)
    prefix, station = id.split('_')
    adapter = client_adapter(ID_PREFIXES[prefix])
    request = adapter&.find_by(id: station)
    mc = Facilities::MultiClient.new 
    responses = mc.run([request])
    results = responses.first
    adapter.class&.from_gis(responses.first.first) unless responses.first.blank? 
  end

  def self.service_whitelist(prefix)
    client_adapter(prefix)&.service_whitelist
  end

  def self.client_adapter(prefix)
    @client_map ||= init_adapters
    @client_map[prefix]
  end

  def self.init_adapters
    {
      HEALTH => VHAFacilityAdapter.new,
      CEMETERY => NCAFacilityAdapter.new,
      BENEFITS => VBAFacilityAdapter.new
    }
  end
end
