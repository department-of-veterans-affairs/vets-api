# frozen_string_literal: true

require 'will_paginate/array'

require_dependency 'va_facilities/application_controller'
require_dependency 'va_facilities/pagination_headers'
require_dependency 'va_facilities/geo_serializer_v1'
require_dependency 'va_facilities/csv_serializer'
require_dependency 'va_facilities/param_validators'

module VaFacilities
  module V1
    class NearbyController < ApplicationController
      include ActionController::MimeResponds
      include VaFacilities::PaginationHeaders
      include VaFacilities::ParamValidators
      skip_before_action(:authenticate)
      before_action :set_default_format
      before_action :validate_params, only: [:index]

      REQUIRED_PARAMS = {
        address: %i[street_address city state zip].freeze,
        lat_lng: %i[lat lng].freeze
      }.freeze
      QUERY_INFO = {
        address: NearbyFacility.method(:query),
        lat_lng: NearbyFacility.method(:query_by_lat_lng)
      }.freeze

      def index
        query_method = get_query_method(params)
        params_hash = params.permit!.to_h.symbolize_keys
        resource = query_method.call(params_hash).paginate(page: params[:page],
                                                           per_page: params[:per_page] || NearbyFacility.per_page)
        respond_to do |format|
          format.json do
            render json: resource,
                   each_serializer: VaFacilities::NearbyFacilitySerializer,
                   meta: metadata(resource)
          end
          format.geojson do
            response.headers['Link'] = link_header(resource)
            render geojson: VaFacilities::GeoSerializerV1.to_geojson(resource)
          end
        end
      end

      protected

      def set_default_format
        request.format = :json if params[:format].nil? && request.headers['HTTP_ACCEPT'].nil?
      end

      private

      def validate_params
        validate_required_nearby_params(REQUIRED_PARAMS)
        validate_street_address
        validate_state_code
        validate_zip
        validate_lat
        validate_lng
        validate_drive_time
        validate_no_services_without_type
        validate_type_and_services_known unless params[:type].nil?
      end

      def get_query_method(params)
        obs_fields = params.keys.map(&:to_sym)
        location_type = REQUIRED_PARAMS.find do |loc_type, req_field_names|
          no_missing_fields = (req_field_names - obs_fields).empty?
          break loc_type if no_missing_fields
        end
        QUERY_INFO[location_type]
      end

      def metadata(resource)
        { pagination: { current_page: resource.current_page,
                        per_page: resource.per_page,
                        total_pages: resource.total_pages,
                        total_entries: resource.total_entries },
          distances: [] }
      end
    end
  end
end
