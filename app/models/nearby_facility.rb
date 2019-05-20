# frozen_string_literal: true

require 'facilities/client'

class NearbyFacility < BaseFacility
  class << self
    attr_writer :validate_on_load

    def query(params)
      require 'json'
      json_from_file = File.read(Rails.root.join('modules', 'va_facilities', 'nearby.json'))
      mocked_response = JSON.parse(json_from_file)
      return mocked_response if params[:street_address] && params[:city] && params[:state] && params[:zip]

      NearbyFacility.none
    end

    def get_facility_data(conditions, type, facility_type, services, additional_data = nil)
      klass = TYPE_MAP[facility_type].constantize
      return klass.none unless type.blank? || type == facility_type
      klass = klass.select(additional_data) if additional_data
      facilities = klass.where(conditions)
      service_conditions = services&.map do |service|
        service_condition(type, service)
      end
      facilities = facilities.where(service_conditions.join(' OR ')) if service_conditions&.any?
      facilities = facilities.where.not(facility_type: DOD_HEALTH)
      facilities
    end

    def service_condition(type, service)
      case type
      when 'benefits'
        "services->'benefits'->'standard' @> '[\"#{service}\"]'"
      when 'health'
        "services->'health' @> '[{\"sl1\":[\"#{service}\"]}]'"
      end
    end

    def per_page
      20
    end

    def max_per_page
      100
    end

    def facility_type_prefix
      super.PREFIX_MAP[facility_type]
    end
  end

  private

  def generate_location
    self.location = "POINT(#{long} #{lat})" if new_record? && !location
  end
end
