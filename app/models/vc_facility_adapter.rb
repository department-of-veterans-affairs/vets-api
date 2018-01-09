# frozen_string_literal: true

class VCFacilityAdapter
  VC_URL = +Settings.locators.vc
  VC_ID_FIELD = 'stationno'
  FACILITY_TYPE = 'vet_center'

  def initialize
    @client = Facilities::Client.new(url: VC_URL, id_field: VC_ID_FIELD)
  end

  def query(bbox, _services)
    @client.query(bbox: bbox.join(','))
  end

  def find_by(id:)
    @client.get(id: id)
  end

  def self.from_gis(record)
    attrs = record['attributes']
    m = from_gis_attrs(TOP_KEYMAP, attrs)
    m[:facility_type] = FACILITY_TYPE
    m[:address] = {}
    m[:address][:physical] = from_gis_attrs(ADDR_KEYMAP, attrs)
    m[:address][:mailing] = {}
    m[:phone] = from_gis_attrs(PHONE_KEYMAP, attrs)
    m[:hours] = {}
    m[:services] = {}
    m[:feedback] = {}
    m[:access] = {}
    VAFacility.new(m)
  end

  def service_whitelist
    []
  end

  TOP_KEYMAP = {
    unique_id: 'stationno', name: 'stationname', classification: FACILITY_TYPE,
    lat: 'lat', long: 'lon'
  }.freeze

  ADDR_KEYMAP = {
    'address_1' => 'address2', 'address_2' => 'address3', 'address_3' => '',
    'city' => 'city', 'state' => 'st', 'zip' => 'zip'
  }.freeze

  PHONE_KEYMAP = {
    'main' => 'sta_phone'
  }.freeze

  HOURS_KEYMAP = %w[
    Monday Tuesday Wednesday Thursday Friday Saturday Sunday
  ].each_with_object({}) { |d, h| h[d] = d }

  # Build a sub-section of the VAFacility model from a flat GIS attribute list,
  # according to the provided key mapping dict. Strip whitespace from string values.
  def self.from_gis_attrs(km, attrs)
    km.each_with_object({}) do |(k, v), h|
      h[k] = (attrs[v].respond_to?(:strip) ? attrs[v].strip : attrs[v])
    end
  end
end
