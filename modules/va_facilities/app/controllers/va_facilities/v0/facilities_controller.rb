# frozen_string_literal: true

require 'will_paginate/array'

require_dependency 'va_facilities/application_controller'
require_dependency 'va_facilities/pagination_headers'
require_dependency 'va_facilities/geo_serializer'
require_dependency 'va_facilities/csv_serializer'
require_dependency 'va_facilities/param_validators'

module VaFacilities
  module V0
    class FacilitiesController < ApplicationController
      include ActionController::MimeResponds
      include VaFacilities::PaginationHeaders
      include VaFacilities::ParamValidators
      skip_before_action(:authenticate)
      before_action :set_default_format
      before_action :validate_params, only: [:index]

      REQUIRE_ONE_PARAM = %i[bbox long lat zip ids state].freeze

      def all
        resource = BaseFacility.where.not(facility_type: BaseFacility::DOD_HEALTH).order(:unique_id)
        respond_to do |format|
          format.geojson do
            render geojson: VaFacilities::GeoSerializer.to_geojson(resource)
          end
          format.csv do
            render csv: VaFacilities::CsvSerializer.to_csv(resource), filename: 'va_facilities'
          end
        end
      end

      def index
        resource = BaseFacility.query(params).paginate(page: params[:page],
                                                       per_page: params[:per_page] || BaseFacility.per_page)
        respond_to do |format|
          format.json do
            render json: resource,
                   each_serializer: VaFacilities::FacilitySerializer,
                   meta: metadata(resource)
          end
          format.geojson do
            response.headers['Link'] = link_header(resource)
            render geojson: VaFacilities::GeoSerializer.to_geojson(resource)
          end
        end
      end

      def show
        results = BaseFacility.find_facility_by_id(params[:id])
        raise Common::Exceptions::RecordNotFound, params[:id] if results.nil?

        respond_to do |format|
          format.json do
            render json: results, serializer: VaFacilities::FacilitySerializer
          end
          format.geojson do
            render geojson: VaFacilities::GeoSerializer.to_geojson(results)
          end
        end
      end

      protected

      def set_default_format
        request.format = :json if params[:format].nil? && request.headers['HTTP_ACCEPT'].nil?
      end

      private

      def validate_params
        validate_a_param_exists(REQUIRE_ONE_PARAM)
        validate_bbox
        validate_state_code
        %i[lat long].each { |param| verify_float(param) } if params.key?(:lat) && params.key?(:long)
        validate_no_services_without_type
        validate_type_and_services_known unless params[:type].nil?
        validate_zip
        valid_location_query?
      end

      def verify_float(param)
        Float(params[param])
      rescue ArgumentError
        raise Common::Exceptions::InvalidFieldValue.new(param.to_s, params[param])
      end

      def metadata(resource)
        meta = { pagination: { current_page: resource.current_page,
                               per_page: resource.per_page,
                               total_pages: resource.total_pages,
                               total_entries: resource.total_entries },
                 distances: [] }
        if params[:lat] && params[:long]
          resource.each do |facility|
            meta[:distances] << { id: ApiSerialization.id(facility),
                                  distance: facility.distance&.round(2) }
          end
        end
        meta
      end
    end
  end
end
