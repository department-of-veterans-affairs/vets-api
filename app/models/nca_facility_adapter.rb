# frozen_string_literal: true

class NCAFacilityAdapter
  NCA_URL = +Settings.locators.nca
  NCA_ID_FIELD = 'SITE_ID'
  FACILITY_TYPE = 'va_cemetery'

  def initialize
    @client = Facilities::Client.new(url: NCA_URL, id_field: NCA_ID_FIELD)
  end

  def query(bbox, _services)
    @client.query(bbox: bbox.join(','))
  end

  def find_by(id:)
    @client.get(id: id)
  end

  def self.from_gis(record)
    attrs = record['attributes']
    m = make_section(V1_TOP_KEYMAP, V2_TOP_KEYMAP, attrs)
    m[:facility_type] = FACILITY_TYPE
    m[:lat] = record['geometry']['y']
    m[:long] = record['geometry']['x']
    m[:address] = {}
    m[:address][:physical] = make_section(V1_ADDR_KEYMAP, V2_ADDR_KEYMAP, attrs)
    m[:address][:mailing] = make_section(V1_MAIL_ADDR_KEYMAP, V2_MAIL_ADDR_KEYMAP, attrs)
    m[:phone] = make_section(V1_PHONE_KEYMAP, V2_PHONE_KEYMAP, attrs)
    m[:hours] = make_section(V1_HOURS_KEYMAP, V2_HOURS_KEYMAP, attrs)
    m[:services] = {}
    m[:feedback] = {}
    m[:access] = {}
    VAFacility.new(m)
  end

  def service_whitelist
    []
  end

  def self.make_section(old_map, new_map, attrs)
    section = from_gis_attrs(old_map, attrs)
    section.merge!(from_gis_attrs(new_map, attrs)) do |_, v1, v2|
      v2.nil? ? v1 : v2
    end
    section
  end

  V1_TOP_KEYMAP = {
    unique_id: 'CEMETERY_I', name: 'FULL_NAME', classification: 'CEM_TYPE',
    website: 'Website_URL'
  }.freeze

  V1_ADDR_KEYMAP = {
    'address_1' => 'CEMETERY_A', 'address_2' => 'CEMETERY_1', 'address_3' => '',
    'city' => 'CEMETERY_C', 'state' => 'CEMETERY_S', 'zip' => 'CEMETERY_Z'
  }.freeze

  V1_MAIL_ADDR_KEYMAP = {
    'address_1' => 'MAIL_ADDRE', 'address_2' => 'MAIL_ADD_1', 'address_3' => '',
    'city' => 'MAIL_CITY', 'state' => 'MAIL_STATE', 'zip' => 'MAIL_ZIP'
  }.freeze

  V1_PHONE_KEYMAP = {
    'main' => 'PHONE', 'fax' => 'FAX'
  }.freeze

  V1_HOURS_KEYMAP = %w(
    Monday Tuesday Wednesday Thursday Friday Saturday Sunday
  ).each_with_object({}) { |d, h| h[d] = d }

  V2_TOP_KEYMAP = {
    unique_id: 'SITE_ID', name: 'FULL_NAME', classification: 'SITE_TYPE',
    website: 'Website_URL'
  }.freeze

  V2_ADDR_KEYMAP = {
    'address_1' => 'SITE_ADDRESS1', 'address_2' => 'SITE_ADDRESS2', 'address_3' => '',
    'city' => 'SITE_CITY', 'state' => 'SITE_STATE', 'zip' => 'SITE_ZIP'
  }.freeze

  V2_MAIL_ADDR_KEYMAP = {
    'address_1' => 'MAIL_ADDRESS1', 'address_2' => 'MAIL_ADDRESS2', 'address_3' => '',
    'city' => 'MAIL_CITY', 'state' => 'MAIL_STATE', 'zip' => 'MAIL_ZIP'
  }.freeze

  V2_PHONE_KEYMAP = {
    'main' => 'PHONE', 'fax' => 'FAX'
  }.freeze

  V2_HOURS_KEYMAP = {
    'Monday' => 'VISITATION_HOURS_WEEKDAY', 'Tuesday' => 'VISITATION_HOURS_WEEKDAY',
    'Wednesday' => 'VISITATION_HOURS_WEEKDAY', 'Thursday' => 'VISITATION_HOURS_WEEKDAY',
    'Friday' => 'VISITATION_HOURS_WEEKDAY', 'Saturday' => 'VISITATION_HOURS_WEEKEND',
    'Sunday' => 'VISITATION_HOURS_WEEKEND'
  }.freeze

  # Build a sub-section of the VAFacility model from a flat GIS attribute list,
  # according to the provided key mapping dict. Strip whitespace from string values.
  def self.from_gis_attrs(km, attrs)
    km.each_with_object({}) do |(k, v), h|
      h[k] = (attrs[v].respond_to?(:strip) ? attrs[v].strip : attrs[v])
    end
  end
end
