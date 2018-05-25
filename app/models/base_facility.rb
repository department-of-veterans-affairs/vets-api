# frozen_string_literal: true

require 'facilities/client'

class BaseFacility < ActiveRecord::Base
  self.inheritance_column = 'facility_type'
  self.primary_key = 'unique_id'
  after_initialize :generate_fingerprint

  YES = 'YES'

  APPROVED_SERVICES = %w[
    MentalHealthCare
    PrimaryCare
    DentalServices
  ].freeze

  HOURS_STANDARD_MAP = DateTime::DAYNAMES.each_with_object({}) { |d, h| h[d] = d }

  HEALTH = 'health'
  CEMETERY = 'cemetery'
  BENEFITS = 'benefits'
  VET_CENTER = 'vet_center'
  DOD_HEALTH = 'dod_health'
  TYPES = [HEALTH, CEMETERY, BENEFITS, VET_CENTER, DOD_HEALTH].freeze

  FACILITY_MAPPINGS = {
    'va_cemetery' => 'Facilities::NCAFacility',
    'va_benefits_facility' => 'Facilities::VBAFacility',
    'vet_center' => 'Facilities::VCFacility',
    'va_health_facility' => 'Facilities::VHAFacility',
    'dod_health' => 'Facilities::DODFacility'
  }.freeze

  TYPE_MAP = {
    CEMETERY => 'Facilities::NCAFacility',
    HEALTH => 'Facilities::VHAFacility',
    BENEFITS => 'Facilities::VBAFacility',
    VET_CENTER => 'Facilities::VCFacility',
    DOD_HEALTH => 'Facilities::DODFacility'
  }.freeze

  TYPE_NAME_MAP = {
    CEMETERY => 'va_cemetery',
    HEALTH => 'va_health_facility',
    BENEFITS => 'va_benefits_facility',
    VET_CENTER => 'vet_center',
    DOD_HEALTH => 'dod_health'
  }.freeze

  FACILITY_SORT_FIELDS = {
    'Facilities::NCAFacility' => %w[NCA_Facilities SITE_ID],
    'Facilities::VBAFacility' => %w[VBA_Facilities Facility_Number],
    'Facilities::VCFacility' => %w[VHA_VetCenters stationno],
    'Facilities::VHAFacility' => %w[VHA_Facilities StationNumber]
  }.freeze

  SERVICE_WHITELIST = {
    HEALTH => %w[Audiology ComplementaryAlternativeMed DentalServices DiagnosticServices ImagingAndRadiology
                 LabServices EmergencyDept EyeCare MentalHealthCare OutpatientMHCare OutpatientSpecMHCare
                 VocationalAssistance OutpatientMedicalSpecialty AllergyAndImmunology CardiologyCareServices
                 DermatologyCareServices Diabetes Dialysis Endocrinology Gastroenterology Hematology
                 InfectiousDisease InternalMedicine Nephrology Neurology Oncology PulmonaryRespiratoryDisease
                 Rheumatology SleepMedicine OutpatientSurgicalSpecialty CardiacSurgery ColoRectalSurgery ENT
                 GeneralSurgery Gynecology Neurosurgery Orthopedics PainManagement PlasticSurgery Podiatry
                 ThoracicSurgery Urology VascularSurgery PrimaryCare Rehabilitation UrgentCare
                 WellnessAndPreventativeCare],
    BENEFITS => %w[ApplyingForBenefits BurialClaimAssistance DisabilityClaimAssistance
                   eBenefitsRegistrationAssistance EducationAndCareerCounseling EducationClaimAssistance
                   FamilyMemberClaimAssistance HomelessAssistance VAHomeLoanAssistance
                   InsuranceClaimAssistanceAndFinancialCounseling PreDischargeClaimAssistance
                   IntegratedDisabilityEvaluationSystemAssistance TransitionAssistance
                   VocationalRehabilitationAndEmploymentAssistance UpdatingDirectDepositInformation],
    CEMETERY => [],
    VET_CENTER => []
  }.freeze

  PENSION_LOCATIONS = %w[310 330 335].freeze

  class << self
    attr_writer :validate_on_load

    def mh_clinic_phone(attrs)
      val = attrs['MHClinicPhone']
      val = attrs['MHPhone'] if val.blank?
      return '' if val.blank?
      result = val.to_s
      result << ' x ' + attrs['Extension'].to_s unless
        (attrs['Extension']).blank? || (attrs['Extension']).zero?
      result
    end

    def to_date(dtstring)
      Date.iso8601(dtstring).iso8601
    end

    def satisfaction_data(attrs)
      result = {}
      datum = FacilitySatisfaction.find(attrs['StationNumber'].upcase)
      if datum.present?
        datum.metrics.each { |k, v| result[k.to_s] = v.present? ? v.round(2) : nil }
        result['effective_date'] = to_date(datum.source_updated)
      end
      result
    end

    def wait_time_data(attrs)
      result = {}
      datum = FacilityWaitTime.find(attrs['StationNumber'].upcase)
      if datum.present?
        datum.metrics.each { |k, v| result[k.to_s] = v }
        result['effective_date'] = to_date(datum.source_updated)
      end
      result
    end

    def zip_plus_four(attrs)
      zip = attrs['Zip']
      zip << "-#{attrs['Zip4']}" unless attrs['Zip4'].to_s.strip.empty?
      zip
    end

    def validate_on_load
      @validate_on_load = true unless defined?(@validate_on_load)
      @validate_on_load
    end

    def find_sti_class(type_name)
      FACILITY_MAPPINGS[type_name].constantize || super
    end

    def sti_name
      FACILITY_MAPPINGS.invert[name]
    end

    def pull_source_data
      metadata = Facilities::MetadataClient.new.get_metadata(FACILITY_SORT_FIELDS[name].first)
      max_record_count = metadata['maxRecordCount']
      Facilities::Client.new.get_all_facilities(*FACILITY_SORT_FIELDS[name], max_record_count).map(&method(:new))
    end

    def find_facility_by_id(id)
      type, unique_id = id.split('_')
      return nil unless type && unique_id
      facility = "Facilities::#{type.upcase}Facility".constantize.find_by(unique_id: unique_id)
      facility&.hours = facility&.hours&.sort_by { |day, _hours| DAYS[day.capitalize] }.to_h
      facility
    end

    def query(params)
      return BaseFacility.none unless params[:bbox]
      bbox_num = params[:bbox].map { |x| Float(x) }
      build_result_set(bbox_num, params[:type], params[:services]).sort_by(&(dist_from_center bbox_num))
    end

    def build_result_set(bbox_num, type, services)
      lats = bbox_num.values_at(1, 3)
      longs = bbox_num.values_at(2, 0)
      conditions = { lat: (lats.min..lats.max), long: (longs.min..longs.max) }
      TYPES.map { |facility_type| get_facility_data(conditions, type, facility_type, services) }.flatten
    end

    def get_facility_data(conditions, type, facility_type, services)
      klass = TYPE_MAP[facility_type].constantize
      return klass.none unless type.blank? || type == facility_type
      facilities = klass.where(conditions)
      facilities = facilities.where("services->'benefits'->'standard' @> '#{services}'") if services&.any?
      facilities = facilities.where.not(facility_type: 'dod_health')
      facilities
    end

    # Naive distance calculation, but accurate enough for map display sorting.
    # If greater precision is ever needed, use Haversine formula.
    def dist_from_center(bbox)
      lambda do |facility|
        center_x = (bbox[0] + bbox[2]) / 2.0
        center_y = (bbox[1] + bbox[3]) / 2.0
        Math.sqrt((facility.long - center_x)**2 + (facility.lat - center_y)**2)
      end
    end

    def per_page
      20
    end

    def max_per_page
      100
    end

    def suggested(facility_types, name_part)
      BaseFacility.where(
        facility_type: facility_types.map { |t| TYPE_NAME_MAP[t] }
      ).where('name ILIKE ?', "%#{name_part}%")
    end
  end

  DAYS = DateTime::DAYNAMES.rotate.each_with_index.map { |day, index| [day, index] }.to_h.freeze

  NCA_MAP = {
    'unique_id' => 'SITE_ID',
    'name' => 'FULL_NAME',
    'classification' => 'SITE_TYPE',
    'website' => 'Website_URL',
    'phone' => { 'main' => 'PHONE', 'fax' => 'FAX' },
    'physical' => { 'address_1' => 'SITE_ADDRESS1', 'address_2' => 'SITE_ADDRESS2',
                    'address_3' => '', 'city' => 'SITE_CITY', 'state' => 'SITE_STATE',
                    'zip' => 'SITE_ZIP' },
    'mailing' => { 'address_1' => 'MAIL_ADDRESS1', 'address_2' => 'MAIL_ADDRESS2',
                   'address_3' => '', 'city' => 'MAIL_CITY', 'state' => 'MAIL_STATE',
                   'zip' => 'MAIL_ZIP' },
    'hours' => { 'Monday' => 'VISITATION_HOURS_WEEKDAY', 'Tuesday' => 'VISITATION_HOURS_WEEKDAY',
                 'Wednesday' => 'VISITATION_HOURS_WEEKDAY', 'Thursday' => 'VISITATION_HOURS_WEEKDAY',
                 'Friday' => 'VISITATION_HOURS_WEEKDAY', 'Saturday' => 'VISITATION_HOURS_WEEKEND',
                 'Sunday' => 'VISITATION_HOURS_WEEKEND' },
    'mapped_fields' => %w[SITE_ID FULL_NAME SITE_TYPE Website_URL SITE_ADDRESS1 SITE_ADDRESS2 SITE_CITY
                          SITE_STATE SITE_ZIP MAIL_ADDRESS1 MAIL_ADDRESS2 MAIL_CITY MAIL_STATE MAIL_ZIP
                          PHONE FAX VISITATION_HOURS_WEEKDAY VISITATION_HOURS_WEEKEND]

  }.freeze
  VBA_MAP = {
    'unique_id' => 'Facility_Number',
    'name' => 'Facility_Name',
    'classification' => 'Facility_Type',
    'website' => 'Website_URL',
    'phone' => { 'main' => 'Phone', 'fax' => 'Fax' },
    'physical' => { 'address_1' => 'Address_1', 'address_2' => 'Address_2',
                    'address_3' => '', 'city' => 'City', 'state' => 'State',
                    'zip' => 'Zip' },
    'hours' => HOURS_STANDARD_MAP,
    'benefits' => {
      'ApplyingForBenefits' => 'Applying_for_Benefits',
      'BurialClaimAssistance' => 'Burial_Claim_assistance',
      'DisabilityClaimAssistance' => 'Disability_Claim_assistance',
      'eBenefitsRegistrationAssistance' => 'eBenefits_Registration',
      'EducationAndCareerCounseling' => 'Education_and_Career_Counseling',
      'EducationClaimAssistance' => 'Education_Claim_Assistance',
      'FamilyMemberClaimAssistance' => 'Family_Member_Claim_Assistance',
      'HomelessAssistance' => 'Homeless_Assistance',
      'VAHomeLoanAssistance' => 'VA_Home_Loan_Assistance',
      'InsuranceClaimAssistanceAndFinancialCounseling' => 'Insurance_Claim_Assistance',
      'IntegratedDisabilityEvaluationSystemAssistance' => 'IDES',
      'PreDischargeClaimAssistance' => 'Pre_Discharge_Claim_Assistance',
      'TransitionAssistance' => 'Transition_Assistance',
      'UpdatingDirectDepositInformation' => 'Updating_Direct_Deposit_Informa',
      'VocationalRehabilitationAndEmploymentAssistance' => 'Vocational_Rehabilitation_Emplo'
    },
    'mapped_fields' => %w[Facility_Number Facility_Name Facility_Type Website_URL Lat Long Other_Services
                          Address_1 Address_2 City State Zip Phone Fax Monday Tuesday Wednesday Thursday
                          Friday Saturday Sunday Applying_for_Benefits Burial_Claim_assistance
                          Disability_Claim_assistance eBenefits_Registration Education_and_Career_Counseling
                          Education_Claim_Assistance Family_Member_Claim_Assistance Homeless_Assistance
                          VA_Home_Loan_Assistance Insurance_Claim_Assistance IDES Pre_Discharge_Claim_Assistance
                          Transition_Assistance Updating_Direct_Deposit_Informa Vocational_Rehabilitation_Emplo]
  }.freeze

  VC_MAP = {
    'unique_id' => 'stationno',
    'name' => 'stationname',
    'classification' => 'vet_center',
    'phone' => { 'main' => 'sta_phone' },
    'physical' => { 'address_1' => 'address2', 'address_2' => 'address3',
                    'address_3' => '', 'city' => 'city', 'state' => 'st',
                    'zip' => 'zip' },
    'hours' => HOURS_STANDARD_MAP.each_with_object({}) { |(k, v), h| h[k.downcase] = v.downcase },
    'mapped_fields' => %w[stationno stationname lat lon address2 address3 city st zip sta_phone
                          monday tuesday wednesday thursday friday saturday sunday]
  }.freeze

  VHA_MAP = {
    'unique_id' => 'StationNumber',
    'name' => 'StationName',
    'classification' => 'CocClassification',
    'website' => 'Website_URL',
    'phone' => { 'main' => 'MainPhone', 'fax' => 'MainFax',
                 'after_hours' => 'AfterHoursPhone',
                 'patient_advocate' => 'PatientAdvocatePhone',
                 'enrollment_coordinator' => 'EnrollmentCoordinatorPhone',
                 'pharmacy' => 'PharmacyPhone', 'mental_health_clinic' => method(:mh_clinic_phone) },
    'physical' => { 'address_1' => 'Street', 'address_2' => 'Building',
                    'address_3' => 'Suite', 'city' => 'City', 'state' => 'State',
                    'zip' => method(:zip_plus_four) },
    'hours' => HOURS_STANDARD_MAP,
    'access' => { 'health' => method(:wait_time_data) },
    'feedback' => { 'health' => method(:satisfaction_data) },
    'services' => {
      'Audiology' => [],
      'ComplementaryAlternativeMed' => [],
      'DentalServices' => [],
      'DiagnosticServices' => %w[
        ImagingAndRadiology LabServices
      ],
      'EmergencyDept' => [],
      'EyeCare' => [],
      'MentalHealthCare' => %w[
        OutpatientMHCare OutpatientSpecMHCare VocationalAssistance
      ],
      'OutpatientMedicalSpecialty' => %w[
        AllergyAndImmunology CardiologyCareServices DermatologyCareServices
        Diabetes Dialysis Endocrinology Gastroenterology
        Hematology InfectiousDisease InternalMedicine
        Nephrology Neurology Oncology
        PulmonaryRespiratoryDisease Rheumatology SleepMedicine
      ],
      'OutpatientSurgicalSpecialty' => %w[
        CardiacSurgery ColoRectalSurgery ENT GeneralSurgery
        Gynecology Neurosurgery Orthopedics PainManagement
        PlasticSurgery Podiatry ThoracicSurgery Urology
        VascularSurgery
      ],
      'PrimaryCare' => [],
      'Rehabilitation' => [],
      'UrgentCare' => [],
      'WellnessAndPreventativeCare' => []
    },
    'mapped_fields' => %w[StationNumber StationName CocClassification FacilityDataDate Website_URL Latitude Longitude
                          Street Building Suite City State Zip Zip4 MainPhone MainFax AfterHoursPhone
                          PatientAdvocatePhone EnrollmentCoordinatorPhone PharmacyPhone MHPhone Extension Monday
                          Tuesday Wednesday Thursday Friday Saturday Sunday SHEP_Primary_Care_Routine
                          SHEP_Primary_Care_Urgent Hematology SHEP_Specialty_Care_Routine SHEP_Specialty_Care_Urgent
                          SHEP_ScoreDateRange PrimaryCare MentalHealthCare DentalServices Audiology ENT
                          ComplementaryAlternativeMed DiagnosticServices ImagingAndRadiology LabServices
                          EmergencyDept EyeCare OutpatientMHCare OutpatientSpecMHCare VocationalAssistance
                          OutpatientMedicalSpecialty AllergyAndImmunology CardiologyCareServices UrgentCare
                          DermatologyCareServices Diabetes Dialysis Endocrinology Gastroenterology InfectiousDisease
                          InternalMedicine Nephrology Neurology Oncology PulmonaryRespiratoryDisease Rheumatology
                          SleepMedicine OutpatientSurgicalSpecialty CardiacSurgery ColoRectalSurgery
                          GeneralSurgery Gynecology Neurosurgery Orthopedics PainManagement PlasticSurgery Podiatry
                          ThoracicSurgery Urology VascularSurgery Rehabilitation WellnessAndPreventativeCare]
  }.freeze

  PATHMAP = { 'NCA_Facilities' => NCA_MAP,
              'VBA_Facilities' => VBA_MAP,
              'VHA_VetCenters' => VC_MAP,
              'VHA_Facilities' => VHA_MAP }.freeze

  private

  def generate_fingerprint
    self.fingerprint = Digest::SHA2.hexdigest(attributes.to_s) if new_record?
  end
end
