# frozen_string_literal: true

require 'will_paginate/array'

require_dependency 'va_facilities/application_controller'
require_dependency 'va_facilities/pagination_headers'
require_dependency 'va_facilities/geo_serializer'
require_dependency 'va_facilities/csv_serializer'

module VaFacilities
  module V1
    class NearbyController < ApplicationController
      include ActionController::MimeResponds
      include VaFacilities::PaginationHeaders
      skip_before_action(:authenticate)
      before_action :set_default_format
      before_action :validate_params, only: [:index]

      REQUIRED_PARAMS = %i[street_address city state zip].freeze
      TYPE_SERVICE_ERR = 'Filtering by services is not allowed unless a facility type is specified'
      MISSING_PARAMS_ERR =
        'Must supply street_address, city, state, and zip to query nearby facilities.'

      def index
        resource = NearbyFacility.query(params).paginate(page: params[:page], per_page: params[:per_page])
        respond_to do |format|
          format.json do
            render json: resource,
                   each_serializer: VaFacilities::NearbyFacilitySerializer,
                   meta: metadata(resource)
          end
          format.geojson do
            response.headers['Link'] = link_header(resource)
            render geojson: VaFacilities::GeoSerializer.to_geojson(resource)
          end
        end
      end

      protected

      def set_default_format
        request.format = :json if params[:format].nil? && request.headers['HTTP_ACCEPT'].nil?
      end

      private

      def validate_params
        validate_required_params
        validate_street_address
        validate_state_code
        validate_zip
        validate_drive_time
        validate_no_services_without_type
        validate_type_and_services_known unless params[:type].nil?
      end

      def validate_required_params
        unless REQUIRED_PARAMS.all? { |param| params.key? param }
          REQUIRED_PARAMS.each do |param|
            unless params.key? param
              raise Common::Exceptions::ParameterMissing.new(param.to_s, detail: MISSING_PARAMS_ERR)
            end
          end
        end
      end

      def validate_street_address
        if params[:street_address]
          raise Common::Exceptions::InvalidFieldValue.new('street_address', params[:street_address]) unless
            params[:street_address].match?(/\d/)
        end
      end

      def validate_state_code
        if params[:state] && STATE_CODES.exclude?(params[:state])
          raise Common::Exceptions::InvalidFieldValue.new('state', params[:state])
        end
      end

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

      def validate_drive_time
        Integer(params[:drive_time]) if params[:drive_time]
      rescue ArgumentError
        raise Common::Exceptions::InvalidFieldValue.new('drive_time', params[:drive_time])
      end

      def validate_no_services_without_type
        if params[:type].nil? && params[:services].present?
          raise Common::Exceptions::ParameterMissing.new('type', detail: TYPE_SERVICE_ERR)
        end
      end

      def validate_type_and_services_known
        raise Common::Exceptions::InvalidFieldValue.new('type', params[:type]) unless
          BaseFacility::TYPES.include?(params[:type])
        unknown = params[:services].to_a - BaseFacility::SERVICE_WHITELIST[params[:type]]
        raise Common::Exceptions::InvalidFieldValue.new('services', unknown) unless unknown.empty?
      end

      def metadata(resource)
        { pagination: { current_page: resource.current_page,
                        per_page: resource.per_page,
                        total_pages: resource.total_pages,
                        total_entries: resource.total_entries } }
      end
    end
  end
end
