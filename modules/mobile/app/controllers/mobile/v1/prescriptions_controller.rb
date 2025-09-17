# frozen_string_literal: true

require 'unified_health_data/service'
require 'unified_health_data/serializers/prescription_serializer'
require 'securerandom'

module Mobile
  module V1
    class PrescriptionsController < Mobile::ApplicationController
      before_action { authorize :mhv_prescriptions, :access? }
      before_action :validate_feature_flag

      def index
        pagination_params

        Rails.logger.info('Mobile V1 Prescriptions API call started')

        prescriptions = unified_health_service.get_prescriptions

        meta = generate_mobile_metadata(prescriptions)
        serialized_data = UnifiedHealthData::Serializers::PrescriptionSerializer.new(prescriptions).serializable_hash
        render json: { **serialized_data, meta: }
      end

      def refill
        # Get all prescriptions to validate IDs and extract station numbers
        prescriptions = unified_health_service.get_prescriptions

        # Build orders array with id and stationNumber for each requested prescription
        orders = ids.map do |prescription_id|
          prescription = prescriptions.find { |p| p.prescription_id == prescription_id.to_s }
          unless prescription
            raise Common::Exceptions::ResourceNotFound.new(detail: "Prescription not found: #{prescription_id}")
          end

          { id: prescription_id.to_s, stationNumber: prescription.station_number }
        end

        result = unified_health_service.refill_prescription(orders)
        render_batch_refill_result(result)
      end

      private

      def unified_health_service
        @unified_health_service ||= UnifiedHealthData::Service.new(current_user)
      end

      def validate_feature_flag
        unless Flipper.enabled?(:mobile_prescriptions_v1, current_user)
          render json: {
            error: {
              code: 'FEATURE_NOT_AVAILABLE',
              message: 'This feature is not currently available'
            }
          }, status: :forbidden
        end
      end

      def generate_mobile_metadata(prescriptions)
        # Legacy signature kept for backwards compatibility inside controller during refactor
        generate_mobile_metadata_with_pagination(
          prescriptions,
          page: params[:page]&.to_i || 1,
          per_page: params[:per_page]&.to_i || 20
        )
      end

      def generate_mobile_metadata_with_pagination(prescriptions, page:, per_page:)
        total_entries = prescriptions.is_a?(Array) ? prescriptions.length : 0
        total_pages = (total_entries.to_f / per_page).ceil

        {
          pagination: {
            current_page: page,
            per_page:,
            total_pages:,
            total_entries:
          },
          prescriptionStatusCount: prescription_status_counts(prescriptions),
          hasNonVaMeds: non_va_meds?(prescriptions)
        }
      end

      def pagination_params
        page = params[:page]&.to_i || 1
        per_page = params[:per_page]&.to_i || 20
        [page, per_page]
      end

      def prescription_filters
        {
          refill_status: params[:refill_status],
          sort: params[:sort] || '-dispensed_date'
        }
      end

      def prescription_status_counts(prescriptions)
        counts = prescriptions.group_by(&:refill_status).transform_values(&:count)
        {
          active: counts['active'] || 0,
          expired: counts['expired'] || 0,
          transferred: counts['transferred'] || 0,
          submitted: counts['submitted'] || 0,
          hold: counts['hold'] || 0,
          discontinued: counts['discontinued'] || 0,
          pending: counts['pending'] || 0,
          unknown: counts['unknown'] || 0
        }
      end

      def non_va_meds?(prescriptions)
        prescriptions.any? { |rx| rx.prescription_source == 'NV' }
      end

      def ids
        ids = params.require(:ids)
        raise Common::Exceptions::InvalidFieldValue.new('ids', ids) unless ids.is_a? Array

        ids.map(&:to_i)
      end

      def render_batch_refill_result(result)
        if result[:success]
          # Use the v1 serializer to maintain consistent format
          render json: Mobile::V1::PrescriptionsRefillsSerializer.new(SecureRandom.uuid, result)
        else
          raise Common::Exceptions::UnprocessableEntity.new(
            detail: result[:error] || 'Unable to process refill request'
          )
        end
      end
    end
  end
end
