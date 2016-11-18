# frozen_string_literal: true
class NCAFacilityAdapter
  NCA_ID_FIELD = 'CEMETERY_I'
  FACILITY_TYPE = 'va_cemetery'

  def self.from_gis(record)
    attrs = record['attributes']
    m = from_gis_attrs(TOP_KEYMAP, attrs)
    m[:facility_type] = FACILITY_TYPE
    m[:lat] = record['geometry']['y']
    m[:long] = record['geometry']['x']
    m[:address] = {}
    m[:address][:physical] = from_gis_attrs(ADDR_KEYMAP, attrs)
    m[:address][:mailing] = from_gis_attrs(MAIL_ADDR_KEYMAP, attrs)
    m[:phone] = from_gis_attrs(PHONE_KEYMAP, attrs)
    m[:hours] = from_gis_attrs(HOURS_KEYMAP, attrs)
    m[:services] = {}
    m[:feedback] = {}
    VAFacility.new(m)
  end

  def self.service_whitelist
    []
  end

  TOP_KEYMAP = {
    unique_id: 'CEMETERY_I', name: 'FULL_NAME', classification: 'CEM_TYPE',
    website: 'Website_URL'
  }.freeze

  ADDR_KEYMAP = {
    'address_1' => 'CEMETERY_A', 'address_2' => 'CEMETERY_1', 'address_3' => '',
    'city' => 'CEMETERY_C', 'state' => 'CEMETERY_S', 'zip' => 'CEMETERY_Z'
  }.freeze

  MAIL_ADDR_KEYMAP = {
    'address_1' => 'MAIL_ADDRE', 'address_2' => 'MAIL_ADD_1', 'address_3' => '',
    'city' => 'MAIL_CITY', 'state' => 'MAIL_STATE', 'zip' => 'MAIL_ZIP'
  }.freeze

  PHONE_KEYMAP = {
    'main' => 'PHONE', 'fax' => 'FAX'
  }.freeze

  HOURS_KEYMAP = %w(
    Monday Tuesday Wednesday Thursday Friday Saturday Sunday
  ).each_with_object({}) { |d, h| h[d] = d }

  # Build a sub-section of the VAFacility model from a flat GIS attribute list,
  # according to the provided key mapping dict. Strip whitespace from string values.
  def self.from_gis_attrs(km, attrs)
    km.each_with_object({}) do |(k, v), h|
      h[k] = (attrs[v].respond_to?(:strip) ? attrs[v].strip : attrs[v])
    end
  end
end
