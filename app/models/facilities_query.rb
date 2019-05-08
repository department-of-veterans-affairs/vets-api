class FacilitiesQuery
  class HighlanderError < StandardError
    def message
      "You may only query by location using ONE of the following parameter sets: lat and long, zip, state, or bbox"
    end
  end

  attr_reader :params

  HEALTH = 'health'
  CEMETERY = 'cemetery'
  BENEFITS = 'benefits'
  VET_CENTER = 'vet_center'
  DOD_HEALTH = 'dod_health'
  TYPES = [HEALTH, CEMETERY, BENEFITS, VET_CENTER, DOD_HEALTH].freeze

  TYPE_MAP = {
    CEMETERY => 'Facilities::NCAFacility',
    HEALTH => 'Facilities::VHAFacility',
    BENEFITS => 'Facilities::VBAFacility',
    VET_CENTER => 'Facilities::VCFacility',
    DOD_HEALTH => 'Facilities::DODFacility'
  }.freeze

  def initialize(params)
    @params = params
  end

  def query
    if location_query_requested?
      query_by_location
    elsif @params[:ids]
      build_result_set_from_ids(params[:ids]).flatten
    else
      BaseFacility.none
    end
  end

  def location_query_requested?
    @params[:state] || (@params[:lat] && @params[:long]) || @params[:zip] || @params[:bbox]
  end

  # Returns a list of facilities based on the type of location param
  def query_by_location
    #  Only one of these params is allowed for logic to continue
    # if (lat_long?) && !(state? || zip? || bbox?)
    #   RadialQuery.new(params).run
    # elsif state? && !(lat_long? || zip? || bbox?)
    #   StateQuery.new(params).run
    # elsif zip? && !(lat_long? || state? || bbox?)
    #   ZipQuery.new(params).run
    # elsif bbox? && !(lat_long? || state? || zip?)
    #   BoundingBoxQuery.new(params).run

    if geo_query?
      query_klass.new(params).run
    else
      # There can only be one
      raise HighlanderError.new
    end
  end

  def query_klasses
    {
      :lat_long? => RadialQuery,
      :zip? => ZipQuery,
      :state? => StateQuery,
      :bbox? => BoundingBoxQuery
    }
  end

  def query_klass
    @query_klass ||= query_klasses.detect{ |k, v|
      params.key?(k) && !(query_klasses.keys - k).detect{ |forbidden_method|
        params.key?(forbidden_method)
      }
    }&.last
  end

  def geo_query?
    !!query_klass
  end

  def lat_long?
    params[:lat] && params[:long]
  end

  def state?
    params[:state]
  end

  def zip?
    params[:zip]
  end

  def bbox?
    params[:bbox]
  end


  def build_result_set_from_ids(ids)
    ids_for_types(ids).map do |facility_type, unique_ids|
      klass = "Facilities::#{facility_type.upcase}Facility".constantize
      klass.where(unique_id: unique_ids)
    end
  end


  def ids_for_types(ids)
    ids.split(',').each_with_object({}) do |type_id, obj|
      facility_type, unique_id = type_id.split('_')
      if facility_type && unique_id
        obj[facility_type] ||= []
        obj[facility_type].push unique_id
      end
    end
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


end

class RadialQuery < FacilitiesQuery

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
    TYPES.map do |facility_type|
      facilities = get_facility_data(
        conditions,
        type,
        facility_type,
        services,
        distance_query(lat, long)
      )
      if ids_map
        ids_for_type = ids_map[PREFIX_MAP[TYPE_NAME_MAP[facility_type]]]
        facilities = facilities.where(unique_id: ids_for_type)
      end
      facilities.order('distance')
    end.flatten
  end
  # rubocop:enable Metrics/ParameterLists

  # The distance attribute is only set if lat/long are sent in as params
  def distance_query(lat, long)
    <<-SQL
      base_facilities.*,
      ST_Distance(base_facilities.location,
      ST_MakePoint(#{long},#{lat})) / #{METERS_PER_MILE} AS distance
    SQL
  end

end


class StateQuery < FacilitiesQuery
  def run
    state = params[:state]
    conditions = "address @> '{ \"physical\": {\"state\": \"#{state}\"}}'"
    TYPES.flat_map do |facility_type|
      get_facility_data(conditions, params[:type], facility_type, params[:services])
    end
  end
end

class ZipQuery < FacilitiesQuery
  def run
    # TODO: allow user to set distance from zip
    zip_plus0 = params[:zip][0...5]
    requested_zip = ZCTA.select { |area| area[0] == zip_plus0 }
    # TODO: iterate over zcta, pushing each zip code that is within distance into an array
    # TODO: change zip criteria to array of zip codes
    conditions = "address ->'physical'->>'zip' ilike '#{requested_zip[0][0]}%'"
    TYPES.flat_map do |facility_type|
      get_facility_data(conditions, params[:type], facility_type, params[:services])
    end
  end
end

class BoundingBoxQuery < FacilitiesQuery

  def run
    bbox_num = @params[:bbox].map { |x| Float(x) }
    build_result_set(bbox_num, @params[:type], @params[:services]).sort_by(&(dist_from_center bbox_num))
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

  def build_result_set(bbox_num, type, services)
    lats = bbox_num.values_at(1, 3)
    longs = bbox_num.values_at(2, 0)
    conditions = { lat: (lats.min..lats.max), long: (longs.min..longs.max) }
    TYPES.flat_map { |facility_type| get_facility_data(conditions, type, facility_type, services) }
  end

end

class IdQuery < FacilitiesQuery

end
