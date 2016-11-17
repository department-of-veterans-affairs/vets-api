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
    services.map { |s| "#{SERVICES_MAP[s]}='YES'" }.join(' AND ') unless services.nil?
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
    m[:feedback] = {}
    VAFacility.new(m)
  end

  def self.service_whitelist
    SERVICES_MAP.keys
  end

  TOP_KEYMAP = {
    unique_id: 'Facility_Number',
    name: 'Facility_Name', classification: 'Facility_Type',
    website: 'First_InternetAddress', lat: 'Lat', long: 'Long'
  }.freeze

  ADDR_KEYMAP = {
    'address_1' => 'Address_1', 'address_2' => 'Address_2', 'address_3' => '',
    'city' => 'City', 'state' => 'State', 'zip' => 'Zip'
  }.freeze

  PHONE_KEYMAP = {
    'main' => 'Phone', 'fax' => 'Fax'
  }.freeze

  HOURS_KEYMAP = %w(
    Monday Tuesday Wednesday Thursday Friday Saturday Sunday
  ).each_with_object({}) { |d, h| h[d] = d }

  SERVICES_MAP = {
    'ApplyingForBenefits' => 'Applying_for_Benefits',
    'BurialClaimAssistance' => 'Burial_Claim_assistance',
    'DisabilityClaimAssistance' => 'Disability_Claim_assistance',
    'eBenefitsRegistrationAssistance' => 'eBenefits_Registration',
    'EducationAndCareerCounseling' => 'Education_and_Career_Counseling',
    'EducationClaimAssistance' => 'Education_Claim_Assistance',
    'FamilyMemberClaimAssistance' => 'Family_Member_Claim_Assistance',
    'HomelessAssistance' => 'Homeless_Assistance',
    'VAHomeLoanAssistance' => 'VA_Home_Loan_Assistance',
    'InsuranceClaimAssistanceAndFinancialCounseling' => 'Insurance_Claim_Assistance_and_',
    'IntegratedDisabilityEvaluationSystemAssistance' => 'IDES',
    'PreDischargeClaimAssistance' => 'Pre_Discharge_Claim_Assistance',
    'TransitionAssistance' => 'Transition Assistance',
    'UpdatingDirectDepositInformation' => 'Updating_Direct_Deposit_Informa',
    'VocationalRehabilitationAndEmploymentAssistance' => 'Vocational_Rehabilitation_Emplo'
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
      l << k if attrs[v] == 'YES'
    end
    services
  end
end
