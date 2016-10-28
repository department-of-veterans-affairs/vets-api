# frozen_string_literal: true
class VBAFacilityAdapter
  VBA_URL = +ENV['VBA_MAPSERVER_URL']
  VBA_ID_FIELD = 'Facility_Number'
  FACILITY_TYPE = 'va_benefits_facility'

  def initialize
    @client = Facilities::Client.new(url: VBA_URL, id_field: VBA_ID_FIELD)
  end

  def query(bbox, services = nil)
    @client.query(bbox: bbox.join(','),
                  where: self.class.where_clause(services))
  end

  def find_by(id:)
    @client.get(id: id)
  end

  def self.where_clause(services)
    services.map { |s| "#{SERVICES_MAP[s]}='Yes'" }.join(' AND ') unless services.nil?
  end

  def self.from_gis(record)
    attrs = record['attributes']
    m = from_gis_attrs(TOP_KEYMAP, attrs)
    m[:facility_type] = FACILITY_TYPE
    m[:address] = {}
    m[:address][:physical] = from_gis_attrs(ADDR_KEYMAP, attrs)
    m[:address][:mailing] = {}
    m[:phone] = from_gis_attrs(PHONE_KEYMAP, attrs)
    m[:hours] = from_gis_attrs(HOURS_KEYMAP, attrs)
    m[:hours][:notes] = attrs['Comments']
    m[:services] = {}
    m[:services][:benefits] = services_from_gis(attrs)
    VAFacility.new(m)
  end

  def service_whitelist
    SERVICES_MAP.keys
  end

  TOP_KEYMAP = {
    unique_id: 'Facility_Number',
    name: 'Facility_Name', classification: 'Classification',
    lat: 'Lat', long: 'Long'
  }.freeze

  ADDR_KEYMAP = {
    'address_1' => 'Address_1', 'address_2' => 'Address__2', 'address_3' => '',
    'city' => 'City_1', 'state' => 'State', 'zip' => 'Zip'
  }.freeze

  PHONE_KEYMAP = {
    'main' => 'Phone', 'fax' => 'Fax'
  }.freeze

  HOURS_KEYMAP = %w(
    Monday Tuesday Wednesday Thursday Friday Saturday Sunday
  ).each_with_object({}) { |d, h| h[d] = d }

  SERVICES_MAP = {
    'ApplyingForBenefits' => 'Apply_Benefits',
    'CareerCounseling' => 'Career_Counseling',
    'SchoolAssistance' => 'School_Assistance',
    'VocationalRehabilitationCareerAssistance' => 'Vocational_Assistance',
    'TransitionAssistance' => 'Transition_Assistance',
    'Pre-dischargeAssistance' => 'Predischarge_Assistance',
    'EmploymentAssistance' => 'Employment_Assistance',
    'FinancialCounseling' => 'Financial_Counseling',
    'HousingAssistance' => 'Housing_Assistance',
    'DisabilityClaimAssistance' => 'Disability_Assistance',
    'EducationClaimAssistance' => 'Education_Assistance',
    'InsuranceClaimAssistance' => 'Insurance_Assistance',
    'VocationalRehabilitationClaimAssistance' => 'Vocationa_Assistance',
    'SurvivorClaimAssistance' => 'Survivor__Assistance',
    'UpdatingContactInformation' => 'Updating_Information',
    'UpdatingDirectDepositInformation' => 'Updating__Deposit_Information',
    'BurialClaimAssistance' => 'Burial_Assistance',
    'eBenefitsLogonAssistance' => 'eBenefits_Assistance',
    'IntegratedDisabilityEvaluationSystem' => 'IDE_System',
    'HomelessAssistance' => 'Homeless_Assistance'
  }.freeze
  OTHER_SERVICES = 'Other_Services'

  # Build a sub-section of the VAFacility model from a flat GIS attribute list,
  # according to the provided key mapping dict. Strip whitespace from string values.
  def self.from_gis_attrs(km, attrs)
    km.each_with_object({}) do |(k, v), h|
      h[k] = (attrs[v].respond_to?(:strip) ? attrs[v].strip : attrs[v])
    end
  end

  # Construct the services sub-section from a flat GIS attribute list.
  def self.services_from_gis(attrs)
    services = {
      'other' => attrs[OTHER_SERVICES]
    }
    services[:standard] = SERVICES_MAP.each_with_object([]) do |(k, v), l|
      l << k if attrs[v] == 'Yes'
    end
    services
  end
end
