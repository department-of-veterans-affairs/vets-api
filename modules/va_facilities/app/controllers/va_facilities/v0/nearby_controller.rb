# frozen_string_literal: true

require 'will_paginate/array'

require_dependency 'va_facilities/application_controller'
require_dependency 'va_facilities/pagination_headers'
require_dependency 'va_facilities/csv_serializer'
require_dependency 'va_facilities/param_validators'

module VaFacilities
  module V0
    class NearbyController < ApplicationController
      include ActionController::MimeResponds
      include VaFacilities::PaginationHeaders
      include VaFacilities::ParamValidators
      skip_before_action(:authenticate)
      before_action :set_default_format
      before_action :set_facility_type
      before_action :set_default_drivetime
      before_action :validate_params, only: [:index]

      PER_PAGE = 20

      REQUIRED_PARAMS = {
        address: %i[street_address city state zip].freeze,
        lat_lng: %i[lat lng].freeze
      }.freeze

      def index
        lat_lng = get_lat_lng(params)
        eligible_ids = Facilities::VHAFacility.with_services(params[:services]).pluck(:unique_id) if params[:services]

        bands = if temporary_service_exceptions_exist?(params[:services])
                  DrivetimeBand.none
                elsif lat_lng.present?
                  DrivetimeBand.find_within_max_distance(lat_lng[:lat], lat_lng[:lng],
                                                         params[:drive_time], eligible_ids)
                               .paginate(page: params[:page], per_page: params[:per_page] || PER_PAGE).load
                else
                  DrivetimeBand.none
                end

        respond_to do |format|
          format.json do
            render json: bands,
                   each_serializer: VaFacilities::NearbySerializer,
                   meta: metadata(bands),
                   links: relationships(bands)
          end
        end
      end

      protected

      def temporary_service_exceptions_exist?(services)
        return false if services.nil?

        services.include?('Podiatry') || services.include?('Nutrition')
      end

      def set_default_format
        request.format = :json if params[:format].nil? && request.headers['HTTP_ACCEPT'].nil?
      end

      def set_facility_type
        params[:type] = 'health'
      end

      def set_default_drivetime
        params[:drive_time] = '30' unless params[:drive_time]
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
        temp_validate_type_and_services_known unless params[:type].nil?
      end

      def temp_validate_type_and_services_known
        raise Common::Exceptions::InvalidFieldValue.new('type', params[:type]) unless
        BaseFacility::TYPES.include?(params[:type])

        # These services are temporarily allowed while we wait to transition to a new srouce for services.
        # The Community Care Eligibility Team needs these services available, and we are the part of the
        # stack that will change in the future, thus this exception. This will rever to the validations in
        # params_validators.rb in the future.
        temporary_service_exceptions = %w[Podiatry Nutrition]

        unknown = params[:services].to_a - facility_klass.service_list - temporary_service_exceptions

        raise Common::Exceptions::InvalidFieldValue.new('services', unknown) unless unknown.empty?
      end

      def get_lat_lng(params)
        obs_fields = params.keys.map(&:to_sym)
        location_type = REQUIRED_PARAMS.keys.find do |loc_type|
          (REQUIRED_PARAMS[loc_type] - obs_fields).empty?
        end

        lat_lng = params.slice(:lat, :lng)
        if location_type.eql? :address
          lat_lng = GeocodingService.new.query(params[:street_address], params[:city], params[:state], params[:zip])
        end
        lat_lng
      end

      def relationships(resource)
        ids = resource.map { |band| "vha_#{band.vha_facility_id}" }.join(',')
        { related: "/services/va_facilities/v0/facilities?ids=#{ids}" }
      end

      def metadata(resource)
        {
          pagination: {
            current_page: resource.try(:current_page),
            per_page: resource.try(:per_page),
            total_pages: resource.try(:total_pages),
            total_entries: resource.try(:total_entries)
          }
        }
      end
    end
  end
end
