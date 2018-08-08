# frozen_string_literal: true

require 'will_paginate/array'

require_dependency 'va_facilities/application_controller'
require_dependency 'va_facilities/geo_serializer'

module VaFacilities
  module V0
    class FacilitiesController < ApplicationController
      include ActionController::MimeResponds
      skip_before_action(:authenticate)
      before_filter :set_default_format
      before_action :validate_params, only: [:index]

      TYPE_SERVICE_ERR = 'Filtering by services is not allowed unless a facility type is specified'

      def index
        resource = BaseFacility.query(params).paginate(page: params[:page], per_page: BaseFacility.per_page)
        respond_to do |format|
          format.json do 
            render json: resource,
              each_serializer: VAFacilitySerializer,
              meta: metadata(resource)
          end
          format.geojson do
            render geojson: VaFacilities::GeoSerializer.to_geojson(resource)
              #adapter: :geojson,
              #each_serializer: VaFacilities::GeoSerializer
          end
        end
      end

      def show
        puts request.headers['HTTP_ACCEPT']
        results = BaseFacility.find_facility_by_id(params[:id])
        raise Common::Exceptions::RecordNotFound, params[:id] if results.nil?
        respond_to do |format|
          puts format
          puts format.inspect
          format.json do
            render json: results, serializer: VAFacilitySerializer
          end
          format.geojson do
            render geojson: VaFacilities::GeoSerializer.to_geojson(results)
              #adapter: :geojson,
              #serializer: VaFacilities::GeoSerializer
          end
        end
      end

      protected
        
        def set_default_format
          request.format = :json if params[:format].nil? && request.headers["HTTP_ACCEPT"].nil?
        end

      private

      def consumer
        request.headers['X-Consumer-Username']
      end

      def validate_params
        validate_bbox
        validate_no_services_without_type
        validate_type_and_services_known unless params[:type].nil?
      end

      def validate_bbox
        if params[:bbox]
          raise ArgumentError unless params[:bbox]&.length == 4
          params[:bbox].each { |x| Float(x) }
        end
      rescue ArgumentError
        raise Common::Exceptions::InvalidFieldValue.new('bbox', params[:bbox])
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
