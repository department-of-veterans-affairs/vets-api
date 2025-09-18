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

        prescriptions = unified_health_service.get_prescriptions(current_only: true)
        has_non_va_meds = non_va_meds? prescriptions
        prescriptions = prescriptions.reject { |item| item.prescription_source == 'NV' }

        meta = generate_mobile_metadata_with_pagination(
          prescriptions:,
          page: params[:page]&.to_i || 1,
          per_page: params[:per_page]&.to_i || 20,
          has_non_va_meds:
        )
        serialized_data = UnifiedHealthData::Serializers::PrescriptionSerializer.new(prescriptions).serializable_hash
        render json: { **serialized_data, meta: }
      end

      def refill
        # Get all prescriptions to validate IDs and extract station numbers
        prescriptions = unified_health_service.get_prescriptions(current_only: true)

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
        @unified_health_service ||= UnifiedHealthData::Service.new(@current_user)
      end

      def validate_feature_flag
        return if Flipper.enabled?(:mhv_medications_cerner_pilot, @current_user)

        render json: {
          error: {
            code: 'FEATURE_NOT_AVAILABLE',
            message: 'This feature is not currently available'
          }
        }, status: :forbidden
      end

      def generate_mobile_metadata_with_pagination(prescriptions:, page:, per_page:, has_non_va_meds:)
        total_entries = prescriptions.is_a?(Array) ? prescriptions.length : 0
        total_pages = (total_entries.to_f / per_page).ceil

        {
          pagination: {
            current_page: page,
            per_page:,
            total_pages:,
            total_entries:
          },
          **status_meta(prescriptions),
          has_non_va_meds:
        }
      end

      def pagination_params
        page = params[:page]&.to_i || 1
        per_page = params[:per_page]&.to_i || 20
        [page, per_page]
      end

      def status_meta(prescriptions)
        {
          prescription_status_count: prescriptions.each_with_object(Hash.new(0)) do |obj, hash|
            hash['isRefillable'] += 1 if obj.is_refillable

            if obj.is_trackable || %w[active submitted providerHold activeParked
                                      refillinprocess].include?(obj.refill_status)
              hash['active'] += 1
            else
              hash[obj.refill_status] += 1
            end
          end
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
