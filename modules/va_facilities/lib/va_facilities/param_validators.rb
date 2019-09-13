# frozen_string_literal: true

# rubocop:disable Metrics/ModuleLength
module VaFacilities
  module ParamValidators
    TYPE_SERVICE_ERR = 'Filtering by services is not allowed unless a facility type is specified'
    MISSING_FACILITIES_PARAMS_ERR =
      'Must supply lat and long, bounding box, zip code, or ids parameter to query facilities data.'
    MISSING_NEARBY_PARAMS_ERR =
      'Must supply street_address, city, state, and zip or lat and lng to query nearby facilities.'
    AMBIGUOUS_PARAMS_ERR =
      'Must supply either street_address, city, state, and zip or lat and lng, not both, to query nearby facilities.'

    def validate_zip
      if params[:zip]
        raise Common::Exceptions::InvalidFieldValue.new('zip', params[:zip]) unless
        params[:zip].match?(/\A\d{5}(-\d{4})?\z/)
        zip_plus0 = params[:zip][0...5]
        requested_zip = ZCTA.select { |area| area[0] == zip_plus0 }
        raise Common::Exceptions::InvalidFieldValue.new('zip', params[:zip]) unless
        requested_zip.any?
      end
    end

    def validate_state_code
      if params[:state] && STATE_CODES.exclude?(params[:state].upcase)
        raise Common::Exceptions::InvalidFieldValue.new('state', params[:state])
      end
    end

    def validate_no_services_without_type
      if params[:type].nil? && params[:services].present?
        raise Common::Exceptions::ParameterMissing.new('type', detail: TYPE_SERVICE_ERR)
      end
    end

    def validate_type_and_services_known
      raise Common::Exceptions::InvalidFieldValue.new('type', params[:type]) unless
      BaseFacility::TYPES.include?(params[:type])
      unknown = params[:services].to_a - facility_klass.service_list
      raise Common::Exceptions::InvalidFieldValue.new('services', unknown) unless unknown.empty?
    end

    def validate_street_address
      if params[:street_address]
        raise Common::Exceptions::InvalidFieldValue.new('street_address', params[:street_address]) unless
            params[:street_address].match?(/\d/)
      end
    end

    def validate_drive_time
      Integer(params[:drive_time]) if params[:drive_time]
    rescue ArgumentError
      raise Common::Exceptions::InvalidFieldValue.new('drive_time', params[:drive_time])
    end

    def validate_lat
      Float(params[:lat]) if params[:lat]
    rescue ArgumentError
      raise Common::Exceptions::InvalidFieldValue.new('lat', params[:lat])
    end

    def validate_lng
      Float(params[:lng]) if params[:lng]
    rescue ArgumentError
      raise Common::Exceptions::InvalidFieldValue.new('lng', params[:lng])
    end

    def validate_bbox
      raise ArgumentError unless params[:bbox].nil? || params[:bbox]&.length == 4
      params[:bbox]&.each { |x| Float(x) }
    rescue ArgumentError
      raise Common::Exceptions::InvalidFieldValue.new('bbox', params[:bbox])
    end

    def validate_a_param_exists(require_one_param)
      lat_and_long = params.key?(:lat) && params.key?(:long)

      if !lat_and_long && require_one_param.none? { |param| params.key? param }
        require_one_param.each do |param|
          unless params.key? param
            raise Common::Exceptions::ParameterMissing.new(param.to_s, detail: MISSING_FACILITIES_PARAMS_ERR)
          end
        end
      end
    end

    def valid_location_query?
      case location_keys
      when [] then true
      when %i[lat long] then true
      when [:state]     then true
      when [:zip]       then true
      when [:bbox]      then true
      else
        # There can only be one
        render json: {
          errors: ['You may only use ONE of these distance query parameter sets: lat/long, zip, state, or bbox']
        },
               status: 422
      end
    end

    def validate_required_nearby_params(required_params)
      param_keys = params.keys.map(&:to_sym)
      address_params = required_params[:address]
      lat_lng_params = required_params[:lat_lng]
      address_difference = (address_params - param_keys)
      lat_lng_difference = (lat_lng_params - param_keys)

      unless valid_params?(address_difference, lat_lng_difference)
        if ambiguous?(address_difference, lat_lng_difference, address_params, lat_lng_params)
          raise Common::Exceptions::ParameterMissing.new(detail: AMBIGUOUS_PARAMS_ERR)
        elsif address_difference != address_params
          raise Common::Exceptions::ParameterMissing.new(address_difference.to_s, detail: MISSING_NEARBY_PARAMS_ERR)
        elsif lat_lng_difference != lat_lng_params
          raise Common::Exceptions::ParameterMissing.new(lat_lng_difference.to_s, detail: MISSING_NEARBY_PARAMS_ERR)
        end
      end
    end

    private

    def valid_params?(difference1, difference2)
      (difference1.empty? && difference2.any?) || (difference2.empty? && difference1.any?)
    end

    def ambiguous?(address_difference, lat_lng_difference, address_params, lat_lng_params)
      address_difference.empty? || lat_lng_difference.empty? ||
        (address_difference != address_params && lat_lng_difference != lat_lng_params)
    end

    def facility_klass
      BaseFacility::TYPE_MAP[params[:type]].constantize
    end

    def location_keys
      (%i[lat long state zip bbox] & params.keys.map(&:to_sym)).sort
    end
  end
end
# rubocop:enable Metrics/ModuleLength
