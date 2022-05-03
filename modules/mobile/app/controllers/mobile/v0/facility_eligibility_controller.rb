# frozen_string_literal: true

module Mobile
  module V0
    class FacilityEligibilityController < ApplicationController
      DEFAULT_PAGE_NUMBER = 1
      DEFAULT_PAGE_SIZE = 3
      SERVICE_TYPES = %w[primaryCare nutrition podiatry optometry audiology].freeze

      def index
        unless SERVICE_TYPES.include?(service_type)
          raise Common::Exceptions::InvalidFieldValue.new('serviceType', service_type)
        end

        page_facilities, page_meta_data = paginate(facility_ids)

        results = Parallel.map(page_facilities, in_processes: page_facilities.size) do |facility_id|
          response = patient_service.get_patient_appointment_metadata(service_type, facility_id,
                                                                      type)
          response.facility_id = facility_id
          response
        end

        render json: Mobile::V0::FacilityEligibilitySerializer.new(results, page_meta_data)
      end

      private

      def patient_service
        VAOS::V2::PatientsService.new(@current_user)
      end

      def pagination_params
        @pagination_params ||= Mobile::V0::Contracts::GetPaginatedList.new.call(
          page_number: params.dig(:page, :number) || DEFAULT_PAGE_NUMBER,
          page_size: params.dig(:page, :size) || DEFAULT_PAGE_SIZE
        )
      end

      def paginate(records)
        url = request.base_url + request.path
        page_records, page_meta_data = Mobile::PaginationHelper.paginate(
          list: records, validated_params: pagination_params, url: url
        )
        # this is temporary. this has come up multiple times and we should develop a better solution
        page_meta_data[:links].transform_values! do |link|
          next if link.nil?

          link += "&serviceType=#{service_type}"
          facility_ids.each do |facility_id|
            link += "&facilityIds[]=#{facility_id}"
          end
          link += "&type=#{type}"

          link
        end

        [page_records, page_meta_data]
      end

      def service_type
        params.require(:serviceType)
      end

      def facility_ids
        params.require(:facilityIds)
      end

      def type
        params.require(:type)
      end
    end
  end
end
