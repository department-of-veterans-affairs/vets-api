# frozen_string_literal: true

module Mobile
  module V0
    class CommunityCareProvidersController < ApplicationController
      # setting pagination values here instead of allowing the pagination helper to handle it
      # because they're also used by the facility service locator
      DEFAULT_PAGE_NUMBER = 1
      DEFAULT_PAGE_SIZE = 10
      RADIUS_MILES = 60 # value used in web app
      SERVICE_TYPES = {
        primaryCare: %w[207QA0505X 363LP2300X 363LA2200X 261QP2300X],
        foodAndNutrition: %w[133V00000X 133VN1201X 133N00000X 133NN1002X],
        podiatry: %w[213E00000X 213EG0000X 213EP1101X 213ES0131X 213ES0103X],
        optometry: %w[152W00000X 152WC0802X],
        audiologyRoutineExam: %w[231H00000X 237600000X 261QH0700X],
        audiologyHearingAidSupport: %w[231H00000X 237600000X]
      }.with_indifferent_access.freeze

      def index
        Rails.logger.info('CC providers call start', user_uuid: @current_user.uuid)
        community_care_providers = ppms_api.facility_service_locator(locator_params)
        page_records, page_meta_data = paginate(community_care_providers)
        serialized = Mobile::V0::CommunityCareProviderSerializer.new(page_records, page_meta_data)
        render json: serialized, status: :ok
      end

      private

      def ppms_api
        FacilitiesApi::V1::PPMS::Client.new
      end

      def locator_params
        specialty_codes = SERVICE_TYPES[params[:serviceType]]
        raise Common::Exceptions::InvalidFieldValue.new('serviceType', params[:serviceType]) if specialty_codes.nil?

        lat, long = coordinates
        {
          latitude: lat,
          longitude: long,
          page: pagination_params[:page_number],
          per_page: pagination_params[:page_size],
          radius: RADIUS_MILES,
          specialties: specialty_codes
        }
      end

      def coordinates
        return facility_coordinates if params[:facilityId]

        Mobile::FacilitiesHelper.user_address_coordinates(@current_user)
      end

      def facility_coordinates
        Rails.logger.info('CC providers call get facilities', facility_id: params[:facilityId])
        facility = Mobile::FacilitiesHelper.get_facilities(Array(params[:facilityId])).first
        raise Common::Exceptions::RecordNotFound, params[:facilityId] unless facility

        [facility.lat, facility.long]
      end

      def pagination_params
        @pagination_params ||= Mobile::V0::Contracts::CommunityCareProviders.new.call(
          page_number: params.dig(:page, :number) || DEFAULT_PAGE_NUMBER,
          page_size: params.dig(:page, :size) || DEFAULT_PAGE_SIZE,
          service_type: params[:serviceType],
          facility_id: params[:facilityId]
        )
      end

      def paginate(records)
        Mobile::PaginationHelper.paginate(
          list: records, validated_params: pagination_params
        )
      end
    end
  end
end
