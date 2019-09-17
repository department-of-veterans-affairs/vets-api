# frozen_string_literal: true

module VaFacilities
  module ParamValidators
    TYPE_SERVICE_ERR = 'Filtering by services is not allowed unless a facility type is specified'

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

    def facility_klass
      BaseFacility::TYPE_MAP[params[:type]].constantize
    end
  end
end
