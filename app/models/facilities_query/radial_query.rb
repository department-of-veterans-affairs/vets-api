# frozen_string_literal: true

module FacilitiesQuery
  class RadialQuery < Base
    METERS_PER_MILE = 1609.344

    def run
      # check for radial limiter if so grab all where distance < distance_query
      limit = Float(params[:radial_limit]) if params[:radial_limit]
      build_distance_result_set(
        Float(params[:lat]),
        Float(params[:long]),
        params[:type],
        params[:services],
        params[:ids],
        limit
      )
    end

    # rubocop:disable Metrics/ParameterLists
    def build_distance_result_set(lat, long, type, services, ids, limit = nil)
      conditions = limit.nil? ? {} : "where distance < #{limit}"
      ids_map = ids_for_types(ids) unless ids.nil?
      result_set = BaseFacility::TYPES.flat_map do |facility_type|
        facilities = get_facility_data(
          conditions,
          type,
          facility_type,
          services,
          distance_query(lat, long)
        )
        if ids_map
          ids_for_type = ids_map[BaseFacility::PREFIX_MAP[BaseFacility::TYPE_NAME_MAP[facility_type]]]
          facilities = facilities.where(unique_id: ids_for_type)
        end
        facilities
      end
      result_set.sort_by(&:distance)
    end
    # rubocop:enable Metrics/ParameterLists

    # The distance attribute is only set if lat/long are sent in as params
    def distance_query(lat, long)
      <<-SQL.squish
        base_facilities.*,
        ST_Distance(base_facilities.location,
        ST_MakePoint(#{long},#{lat})) / #{METERS_PER_MILE} AS distance
      SQL
    end
  end
end
