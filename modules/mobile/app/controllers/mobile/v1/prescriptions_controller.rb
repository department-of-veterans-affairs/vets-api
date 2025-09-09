# frozen_string_literal: true

module Mobile
  module V1
    class PrescriptionsController < ApplicationController
      before_action { authorize :mhv_prescriptions, :access? }
      before_action :check_cerner_pilot_access

      def index
        Rails.logger.info(
          message: 'Mobile v1 prescriptions accessed via UHD',
          user_icn: @current_user.icn,
          service: 'mobile_v1_prescriptions'
        )

        # Fetch prescriptions from UHD service
        uhd_prescriptions = uhd_service.get_prescriptions

        # Transform UHD data to mobile format
        mobile_prescriptions = transformer.transform(uhd_prescriptions)

        # Paginate results
        page_resource, page_meta_data = paginate(mobile_prescriptions)

        # Add UHD-specific metadata
        page_meta_data[:meta].merge!(
          data_source: 'unified_health_data'
        )

        render json: Mobile::V1::PrescriptionsSerializer.new(page_resource, page_meta_data)
      end

      def refill
        Rails.logger.info(
          message: 'Mobile v1 prescription refill via UHD',
          user_icn: @current_user.icn,
          prescription_ids: ids,
          service: 'mobile_v1_prescriptions'
        )

        # Use UHD service for refill
        uhd_response = uhd_service.refill_prescription(ids)

        # Transform UHD refill response to v0 API format
        transformed_response = refill_transformer.transform(uhd_response)

        render json: Mobile::V1::PrescriptionsRefillsSerializer.new(@current_user.uuid, transformed_response)
      end

      def tracking
        Rails.logger.info(
          message: 'Mobile v1 prescription tracking requested - not yet implemented',
          user_icn: @current_user.icn,
          prescription_id: params[:id],
          service: 'mobile_v1_prescriptions'
        )

        render json: {
          errors: [{
            code: 'not_implemented',
            detail: 'Prescription tracking will be available in a future update'
          }]
        }, status: :not_implemented
      end

      private

      def check_cerner_pilot_access
        unless Flipper.enabled?(:mhv_medications_cerner_pilot, @current_user)
          raise Common::Exceptions::Forbidden, detail: 'Access to UHD prescriptions not authorized'
        end
      end

      def uhd_service
        @uhd_service ||= UnifiedHealthData::Service.new(@current_user)
      end

      def transformer
        @transformer ||= Mobile::V1::Prescriptions::Transformer.new
      end

      def refill_transformer
        @refill_transformer ||= Mobile::V1::Prescriptions::RefillTransformer.new
      end

      def paginate(records)
        Mobile::PaginationHelper.paginate(list: records, validated_params: pagination_params)
      end

      def pagination_params
        @pagination_params ||= Mobile::V0::Contracts::Prescriptions.new.call(
          page_number: params.dig(:page, :number),
          page_size: params.dig(:page, :size)
        )
      end

      def ids
        ids = params.require(:ids)
        raise Common::Exceptions::InvalidFieldValue.new('ids', ids) unless ids.is_a?(Array)

        ids.map(&:to_i)
      end
    end
  end
end