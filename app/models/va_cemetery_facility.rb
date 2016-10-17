# frozen_string_literal: true
require_dependency 'facilities/client'

class VACemeteryFacility < ActiveModelSerializers::Model
  attr_accessor :station_number, :district, :name, :status, :lat, :long,
                :address, :mailing_address, :phone

  def self.query(bbox:)
    results = client.query(bbox: bbox.join(','))
    results.each_with_object([]) do |record, facs|
      facs << VACemeteryFacility.from_gis(record)
    end
  end

  def self.find_by_id(id:)
    results = client.get(identifier: id)
    VACemeteryFacility.from_gis(results.first) unless results.blank?
  end

  def self.from_gis(record)
    attrs = record['attributes']
    m = VACemeteryFacility.from_gis_attrs(TOP_KEYMAP, attrs)
    m[:lat] = record['geometry']['y']
    m[:long] = record['geometry']['x']
    m[:address] = VACemeteryFacility.from_gis_attrs(ADDR_KEYMAP, attrs)
    m[:mailing_address] = VACemeteryFacility.from_gis_attrs(MAIL_ADDR_KEYMAP, attrs)
    m[:phone] = VACemeteryFacility.from_gis_attrs(PHONE_KEYMAP, attrs)
    VACemeteryFacility.new(m)
  end

  TOP_KEYMAP = {
    station_number: 'CEMETERY_I', district: 'DISTRICT',
    name: 'FULL_NAME', status: 'STATUS'
  }.freeze

  ADDR_KEYMAP = {
    'address1' => 'CEMETERY_A', 'address2' => 'CEMETERY_1',
    'city' => 'CEMETERY_C', 'state' => 'CEMETERY_S', 'zip' => 'CEMETERY_Z'
  }.freeze

  MAIL_ADDR_KEYMAP = {
    'address1' => 'MAIL_ADDRE', 'address2' => 'MAIL_ADD_1',
    'city' => 'MAIL_CITY', 'state' => 'MAIL_STATE', 'zip' => 'MAIL_ZIP'
  }.freeze

  PHONE_KEYMAP = {
    'main' => 'PHONE', 'fax' => 'FAX'
  }.freeze

  def self.from_gis_attrs(km, attrs)
    km.each_with_object({}) do |(k, v), h|
      h[k] = attrs[v]
    end
  end

  URL = +ENV['NCA_MAPSERVER_URL']
  LAYER = ENV['NCA_MAPSERVER_LAYER']
  ID_FIELD = 'CEMETERY_I'

  def self.client
    @client ||= Facilities::Client.new(url: URL, layer: LAYER, id_field: ID_FIELD)
  end
end
