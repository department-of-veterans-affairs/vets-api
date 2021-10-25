# frozen_string_literal: true

module FacilitiesQuery
  class Base
    attr_reader :params

    def initialize(params)
      @params = params
    end

    # This is the default response. It is overriden in the child classes
    def run
      BaseFacility.none
    end

    def get_facility_data(conditions, type, facility_type, services, additional_data = nil)
      klass = BaseFacility::TYPE_MAP[facility_type].constantize
      return klass.none unless type.blank? || type == facility_type

      klass = klass.select(additional_data) if additional_data
      facilities = klass.where(conditions)
      service_conditions = services&.map do |service|
        service_condition(type, service)
      end
      facilities = facilities.where(service_conditions.join(' OR ')) if service_conditions&.any?
      facilities.where.not(facility_type: BaseFacility::DOD_HEALTH)
    end

    def service_condition(type, service)
      case type
      when 'benefits'
        "services->'benefits'->'standard' @> '[\"#{service}\"]'"
      when 'health'
        "services->'health' @> '[{\"sl1\":[\"#{service}\"]}]'"
      end
    end

    def ids_for_types(ids)
      ids.split(',').each_with_object(Hash.new { |h, k| h[k] = [] }) do |type_id, obj|
        facility_type, unique_id = type_id.split('_')
        obj[facility_type].push unique_id if facility_type && unique_id
      end
    end
  end
end
