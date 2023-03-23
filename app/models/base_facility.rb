# frozen_string_literal: true

require 'facilities/client'

class BaseFacility < ApplicationRecord
  self.inheritance_column = 'facility_type'
  self.primary_key = 'unique_id'
  after_initialize :generate_fingerprint
  after_initialize :generate_location

  YES = 'YES'

  HOURS_STANDARD_MAP = {
    'Sunday' => 'Sunday',
    'Monday' => 'Monday',
    'Tuesday' => 'Tuesday',
    'Wednesday' => 'Wednesday',
    'Thursday' => 'Thursday',
    'Friday' => 'Friday',
    'Saturday' => 'Saturday'
  }.freeze

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

  PENSION_LOCATIONS = %w[310 330 335].freeze

  class << self
    # This is only mutated in specs for the purpose of testing
    # rubocop:disable ThreadSafety/ClassAndModuleAttributes
    attr_writer :validate_on_load

    # rubocop:enable ThreadSafety/ClassAndModuleAttributes

    def to_date(dtstring)
      Date.iso8601(dtstring).iso8601
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

      facility = "Facilities::#{type.upcase}Facility".constantize.find_by(unique_id:)
      facility&.hours = facility&.hours&.sort_by { |day, _hours| DAYS[day.capitalize] }.to_h
      facility
    end

    def query(params)
      FacilitiesQuery.generate_query(params).run
    end

    def per_page
      10
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
