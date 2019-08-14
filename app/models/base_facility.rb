# frozen_string_literal: true

require 'facilities/client'
require_relative './facilities_query/facilities_query'

class BaseFacility < ApplicationRecord
  self.inheritance_column = 'facility_type'
  self.primary_key = 'unique_id'
  after_initialize :generate_fingerprint
  after_initialize :generate_location

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

  PREFIX_MAP = {
    'va_health_facility' => 'vha',
    'va_benefits_facility' => 'vba',
    'va_cemetery' => 'nca',
    'vet_center' => 'vc'
  }.freeze

  FACILITY_MAPPINGS = {
    'va_cemetery' => 'Facilities::NCAFacility',
    'va_benefits_facility' => 'Facilities::VBAFacility',
    'vet_center' => 'Facilities::VCFacility',
    'va_health_facility' => 'Facilities::VHAFacility',
    'dod_health' => 'Facilities::DODFacility'
  }.freeze

  CLASS_MAP = {
    'nca' => Facilities::NCAFacility,
    'vha' => Facilities::VHAFacility,
    'vba' => Facilities::VBAFacility,
    'vc' => Facilities::VCFacility
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

  SERVICE_WHITELIST = {
    HEALTH => %w[PrimaryCare MentalHealthCare DentalServices UrgentCare EmergencyCare Audiology Cardiology Dermatology
                 Gastroenterology Gynecology Ophthalmology Optometry Orthopedics Urology WomensHealth],
    BENEFITS => %w[ApplyingForBenefits BurialClaimAssistance DisabilityClaimAssistance
                   eBenefitsRegistrationAssistance EducationAndCareerCounseling EducationClaimAssistance
                   FamilyMemberClaimAssistance HomelessAssistance VAHomeLoanAssistance Pensions
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
        datum.metrics.each { |k, v| result[k.to_s] = v.present? ? v.round(2).to_f : nil }
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

    def find_facility_by_id(id)
      type, unique_id = id.split('_')
      return nil unless type && unique_id
      facility = "Facilities::#{type.upcase}Facility".constantize.find_by(unique_id: unique_id)
      facility&.hours = facility&.hours&.sort_by { |day, _hours| DAYS[day.capitalize] }.to_h
      facility
    end

    def query(params)
      FacilitiesQuery.generate_query(params).run
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

  PATHMAP = { 'NCA_Facilities' => Facilities::NCAFacility::NCA_MAP,
              'VBA_Facilities' => Facilities::VBAFacility::VBA_MAP,
              'VHA_VetCenters' => Facilities::VCFacility::VC_MAP,
              'VHA_Facilities' => Facilities::VHAFacility::VHA_MAP }.freeze

  def facility_type_prefix
    PREFIX_MAP[facility_type]
  end

  private

  def generate_location
    self.location = "POINT(#{long} #{lat})" if new_record? && !location
  end

  def generate_fingerprint
    self.fingerprint = Digest::SHA2.hexdigest(attributes.to_s) if new_record?
  end
end
