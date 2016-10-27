# frozen_string_literal: true
require 'facilities/client'

class VAFacility < ActiveModelSerializers::Model
  attr_accessor :unique_id, :name, :facility_type, :classification, :lat, :long,
                :address, :phone, :hours, :services

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
    query_types.each_with_object([]) do |t, facilities|
      adapter = client_adapter(t)
      results = adapter.query(bbox, services)
      results&.each do |record|
        facilities << adapter.class.from_gis(record)
      end
    end
  end

  def self.find_by(id:)
    prefix, station = id.split('_')
    adapter = client_adapter(ID_PREFIXES[prefix])
    results = adapter&.find_by(id: station)
    adapter.class&.from_gis(results.first) unless results.blank?
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
