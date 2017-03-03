# frozen_string_literal: true
require 'facilities/async_client'
require 'facilities/multi_client'

class VAFacility < ActiveModelSerializers::Model
  attr_accessor :unique_id, :name, :facility_type, :classification, :website,
                :lat, :long, :address, :phone, :hours, :services, :feedback,
                :access

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
    bbox_num = bbox.map { |x| Float(x) }
    requests = query_types.map { |t| client_adapter(t).query(bbox_num, services) }
    responses = multi_client.run(requests)
    facilities = []
    query_types.zip(responses).each do |(t, rs)|
      adapter = client_adapter(t)
      rs&.each do |record|
        facilities << adapter.class.from_gis(record)
      end
    end
    facilities.sort_by(&(dist_from_center bbox_num))
  end

  # Naive distance calculation, but accurate enough for map display sorting.
  # If greater precision is ever needed, use Haversine formula.
  def self.dist_from_center(bbox)
    lambda do |facility|
      center_x = (bbox[0] + bbox[2]) / 2.0
      center_y = (bbox[1] + bbox[3]) / 2.0
      Math.sqrt((facility.long - center_x)**2 + (facility.lat - center_y)**2)
    end
  end

  def self.find_by(id:)
    prefix, station = id.split('_')
    adapter = client_adapter(ID_PREFIXES[prefix])
    return nil unless adapter
    request = adapter.find_by(id: station)
    responses = multi_client.run([request])
    adapter.class&.from_gis(responses.first.first) unless responses.first.blank?
  end

  def self.service_whitelist(prefix)
    client_adapter(prefix)&.service_whitelist
  end

  def self.multi_client
    @mc ||= Facilities::MultiClient.new
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

  def self.per_page
    20
  end

  def self.max_per_page
    100
  end
end
