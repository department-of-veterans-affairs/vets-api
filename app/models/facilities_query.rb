# frozen_string_literal: true

class FacilitiesQuery
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
    ids.split(',').each_with_object(Hash.new{|h,k| h[k] = []}) do |type_id, obj|
      facility_type, unique_id = type_id.split('_')
      obj[facility_type].push unique_id if (facility_type && unique_id)
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

class RadialQuery < FacilitiesQuery
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
    BaseFacility::TYPES.flat_map do |facility_type|
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
      facilities.order('distance')
    end
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
    BaseFacility::TYPES.flat_map do |facility_type|
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
    BaseFacility::TYPES.flat_map do |facility_type|
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
    BaseFacility::TYPES.flat_map { |facility_type| get_facility_data(conditions, type, facility_type, services) }
  end
end
