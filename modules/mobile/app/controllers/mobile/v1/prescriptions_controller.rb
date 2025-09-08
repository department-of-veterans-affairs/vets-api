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

        # Apply filtering if provided
        if params[:filter].present?
          mobile_prescriptions = apply_filters(mobile_prescriptions)
        end

        # Apply sorting
        mobile_prescriptions = apply_sorting(mobile_prescriptions)

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

      def apply_filters(prescriptions)
        filter_params_hash = filter_params.to_h
        
        prescriptions.select do |prescription|
          filter_params_hash.all? do |key, value|
            case key.to_sym
            when :refill_status
              prescription.refill_status == value
            when :is_refillable
              prescription.is_refillable == (value == 'true')
            when :is_trackable
              prescription.is_trackable == (value == 'true')
            else
              true
            end
          end
        end
      end

      def apply_sorting(prescriptions)
        # Default sort by prescription_name if no sort specified
        sort_param = params[:sort] || 'prescription_name'
        
        case sort_param
        when 'prescription_name'
          prescriptions.sort_by { |p| p.prescription_name || '' }
        when '-prescription_name'
          prescriptions.sort_by { |p| p.prescription_name || '' }.reverse
        when 'ordered_date'
          prescriptions.sort_by { |p| p.ordered_date || '' }
        when '-ordered_date'
          prescriptions.sort_by { |p| p.ordered_date || '' }.reverse
        when 'refill_date'
          prescriptions.sort_by { |p| p.refill_date || '' }
        when '-refill_date'
          prescriptions.sort_by { |p| p.refill_date || '' }.reverse
        else
          prescriptions.sort_by { |p| p.prescription_name || '' }
        end
      end

      def paginate(records)
        Mobile::PaginationHelper.paginate(list: records, validated_params: pagination_params)
      end

      def pagination_params
        @pagination_params ||= Mobile::V0::Contracts::Prescriptions.new.call(
          page_number: params.dig(:page, :number),
          page_size: params.dig(:page, :size),
          filter: params[:filter].present? ? filter_params.to_h : nil,
          sort: params[:sort]
        )
      end

      def filter_params
        @filter_params ||= begin
          return {} unless params[:filter]
          
          valid_filter_params = params.require(:filter).permit(:refill_status, :is_refillable, :is_trackable)
          valid_filter_params.empty? ? {} : valid_filter_params
        end
      end

      def ids
        ids = params.require(:ids)
        raise Common::Exceptions::InvalidFieldValue.new('ids', ids) unless ids.is_a? Array

        ids.map(&:to_i)
      end
    end
  end
end