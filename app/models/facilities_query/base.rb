# frozen_string_literal: true

module FacilitiesQuery
  class Base
    attr_reader :params

    def initialize(params)
      @params = params
    end

    def query
      if valid_location_query?
        location_query_klass.new(params).run
      elsif @params[:ids]
        build_result_set_from_ids(params[:ids]).flatten
      else
        BaseFacility.none
      end
    end

    # Massages the location_query_klass return value to be boolean
    def valid_location_query?
      !location_query_klass.nil?
    end

    # When given more than one type of distance query param,
    # return nil because the app will not choose preference for the user.
    # In the controller, this logic is somewhat duplicated
    # and will render an error when given multiple params.
    # In the case that only one of these types is given,
    # return the class used to make that type of query.
    def location_query_klass
      @location_query_klass ||= case location_keys
                                when %i[lat long] then RadialQuery
                                when [:state]     then StateQuery
                                when [:zip]       then ZipQuery
                                when [:bbox]      then BoundingBoxQuery
                                end
    end

    def location_keys
      (%i[lat long state zip bbox] & params.keys.map(&:to_sym)).sort
    end

    def build_result_set_from_ids(ids)
      ids_for_types(ids).map do |facility_type, unique_ids|
        klass = "Facilities::#{facility_type.upcase}Facility".constantize
        klass.where(unique_id: unique_ids)
      end
    end

    def ids_for_types(ids)
      ids.split(',').each_with_object(Hash.new { |h, k| h[k] = [] }) do |type_id, obj|
        facility_type, unique_id = type_id.split('_')
        obj[facility_type].push unique_id if facility_type && unique_id
      end
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
      facilities = facilities.where.not(facility_type: BaseFacility::DOD_HEALTH)
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
  end
end
