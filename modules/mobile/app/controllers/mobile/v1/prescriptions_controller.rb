# frozen_string_literal: true

module Mobile
  module V1
    class PrescriptionsController < ApplicationController
      before_action :authenticate_user!
      before_action :validate_feature_flag

      def index
        page, per_page = pagination_params

        Rails.logger.info('Mobile V1 Prescriptions API call started')
        
        prescriptions = unified_health_service.get_prescriptions

        # TODO: Add pagination and filtering logic for page, per_page, refill_status, sort
        
        meta = generate_mobile_metadata(prescriptions, page:, per_page:)
        render json: { data: prescriptions, meta: }, serializer: Mobile::V1::PrescriptionsSerializer
      end

      def show
        Rails.logger.info("Mobile V1 Prescription detail request for ID: #{params[:id]}")
        
        # Note: UnifiedHealthData::Service doesn't have get_prescription method yet
        # For now, get all prescriptions and find the specific one
        prescriptions = unified_health_service.get_prescriptions
        prescription = prescriptions.find { |p| p.prescription_id == params[:id] }
        
        raise Common::Exceptions::ResourceNotFound.new(nil, detail: 'Prescription not found') unless prescription

        render json: prescription, serializer: Mobile::V1::PrescriptionsSerializer
      end

      def refill
        Rails.logger.info("Mobile V1 Prescription refill request for ID: #{params[:id]}")
        
        # Note: The refill_prescription method expects an array of orders with id and stationNumber
        # For now, we'll need to get the prescription first to extract the station number
        prescriptions = unified_health_service.get_prescriptions
        prescription = prescriptions.find { |p| p.prescription_id == params[:id] }
        
        raise Common::Exceptions::ResourceNotFound.new(nil, detail: 'Prescription not found') unless prescription
        
        orders = [{ id: params[:id], stationNumber: prescription.station_number }]
        result = unified_health_service.refill_prescription(orders)
        render_refill_result(result)
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
          per_page: [params[:per_page]&.to_i || 20, 50].min
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
        per_page = [params[:per_page]&.to_i || 20, 50].min
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
        prescriptions.any? { |rx| rx.prescription_source != 'va' }
      end

      def render_refill_result(result)
        if result[:success]
          render json: {
            data: {
              prescription_id: params[:id],
              refill_status: result[:refill_status],
              refill_date: result[:refill_date]
            }
          }, status: :ok
        else
          raise Common::Exceptions::UnprocessableEntity.new(
            detail: (result[:error] || 'Unable to process refill request')
          )
        end
      end
    end
  end
end
