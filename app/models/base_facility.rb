# frozen_string_literal: true

require 'facilities/shared_client'

class BaseFacility < ActiveRecord::Base
  self.inheritance_column = 'facility_type'
  self.primary_key = 'unique_id'
  after_initialize :generate_fingerprint

  HEALTH = 'health'
  CEMETERY = 'cemetery'
  BENEFITS = 'benefits'
  VET_CENTER = 'vet_center'
  TYPES = [HEALTH, CEMETERY, BENEFITS, VET_CENTER].freeze

  FACILITY_MAPPINGS = {
    'va_cemetery' => 'Facilities::NCAFacility',
    'va_benefits_facility' => 'Facilities::VBAFacility',
    'vet_center' => 'Facilities::VCFacility',
    'va_health_facility' => 'Facilities::VHAFacility'
  }.freeze

  TYPE_MAP = {
    CEMETERY => 'Facilities::NCAFacility',
    HEALTH => 'Facilities::VHAFacility',
    BENEFITS => 'Facilities::VBAFacility',
    VET_CENTER => 'Facilities::VCFacility'
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
    BENEFITS => %w[ApplyingForBenefits BurialClaimAssistance DisabilityClaimAssistance eBenefitsRegistrationAssistance
                   EducationAndCareerCounseling EducationClaimAssistance FamilyMemberClaimAssistance HomelessAssistance
                   VAHomeLoanAssistance InsuranceClaimAssistanceAndFinancialCounseling PreDischargeClaimAssistance
                   IntegratedDisabilityEvaluationSystemAssistance VocationalRehabilitationAndEmploymentAssistance
                   TransitionAssistance UpdatingDirectDepositInformation],
    CEMETERY => [],
    VET_CENTER => []
  }.freeze

  class << self
    def find_sti_class(type_name)
      FACILITY_MAPPINGS[type_name].constantize || super
    end

    def sti_name
      FACILITY_MAPPINGS.invert[name]
    end

    def pull_source_data
      metadata = Facilities::MetadataClient.new.get_metadata(FACILITY_SORT_FIELDS[name].first)
      max_record_count = metadata['maxRecordCount']
      Facilities::SharedClient.new.get_all_facilities(*FACILITY_SORT_FIELDS[name], max_record_count).map(&method(:new))
    end

    def find_facility_by_id(id)
      type, unique_id = id.split('_')
      return nil unless type && unique_id
      "Facilities::#{type.upcase}Facility".constantize.find_by(unique_id: unique_id)
    end

    def query(params)
      bbox_num = params[:bbox].map { |x| Float(x) }
      data = build_result_set(bbox_num, params[:type], params[:services])
      Common::Collection.new(::VAFacility, data: data.sort_by(&(dist_from_center bbox_num)))
    end

    def build_result_set(bbox_num, type, services)
      lats = bbox_num.values_at(1, 3)
      longs = bbox_num.values_at(2, 0)
      conditions = { lat: coord_range(lats), long: coord_range(longs) }
      TYPES.map { |facility_type| get_facility_data(conditions, type, facility_type, services) }.flatten
    end

    def get_facility_data(conditions, type, facility_type, services)
      return [] unless type.blank? || type == facility_type
      facilities = TYPE_MAP[facility_type].constantize.where(conditions)
      facilities = facilities.where("services->'benefits'->'standard' @> '#{services}'") if services&.any?
      facilities
    end

    def dist_from_center(bbox)
      lambda do |facility|
        center_x = (bbox[0] + bbox[2]) / 2.0
        center_y = (bbox[1] + bbox[3]) / 2.0
        Math.sqrt((facility.long - center_x)**2 + (facility.lat - center_y)**2)
      end
    end

    def coord_range(coords)
      coords.min..coords.max
    end

    def service_whitelist(type)
      SERVICE_WHITELIST[type]
    end
  end

  private

  def generate_fingerprint
    self.fingerprint = Digest::SHA2.hexdigest(attributes.to_s) if new_record?
  end
end
