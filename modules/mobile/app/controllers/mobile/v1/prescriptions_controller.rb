# frozen_string_literal: true

require 'unified_health_data/service'
require 'unified_health_data/serializers/prescription_serializer'
require 'unified_health_data/serializers/prescriptions_refills_serializer'
require 'securerandom'
require 'unique_user_events'

module Mobile
  module V1
    class PrescriptionsController < Mobile::ApplicationController
      before_action { authorize :mhv_prescriptions, :access? }
      before_action :validate_feature_flag

      def index
        all_prescriptions = fetch_prescriptions
        pruned = filtered_prescriptions(all_prescriptions)
        paged, page_meta = paginate_prescriptions(pruned)
        meta = build_meta(full_list: pruned, page_meta:, originals: all_prescriptions)

        # Log unique user event for prescriptions accessed
        UniqueUserEvents.log_event(
          user: @current_user,
          event_name: UniqueUserEvents::EventRegistry::PRESCRIPTIONS_ACCESSED
        )

        serialized = UnifiedHealthData::Serializers::PrescriptionSerializer.new(paged).serializable_hash
        render json: { **serialized, meta: }
      rescue Common::Exceptions::BackendServiceException
        raise Common::Exceptions::BackendServiceException, 'MOBL_502_upstream_error'
      end

      def refill
        parsed_orders = orders
        result = unified_health_service.refill_prescription(parsed_orders)
        response = UnifiedHealthData::Serializers::PrescriptionsRefillsSerializer.new(SecureRandom.uuid, result)
        raise Common::Exceptions::BackendServiceException, 'MOBL_502_upstream_error' unless response

        # Log unique user event for prescription refill requested (includes OH tracking for matching facilities)
        event_facility_ids = parsed_orders.map { |order| order['stationNumber'] }.compact.uniq
        UniqueUserEvents.log_event(
          user: @current_user,
          event_name: UniqueUserEvents::EventRegistry::PRESCRIPTIONS_REFILL_REQUESTED,
          event_facility_ids:
        )

        render json: response.serializable_hash
      end

      private

      def unified_health_service
        @unified_health_service ||= UnifiedHealthData::Service.new(@current_user)
      end

      def fetch_prescriptions
        unified_health_service.get_prescriptions(current_only: true)
      end

      def filtered_prescriptions(list)
        list.reject { |item| item.prescription_source == 'NV' }
      end

      def pagination_contract
        Mobile::V0::Contracts::Prescriptions.new.call(
          page_number: params.dig(:page, :number),
          page_size: params.dig(:page, :size),
          filter: nil,
          sort: params[:sort]
        )
      end

      def paginate_prescriptions(list)
        Mobile::PaginationHelper.paginate(list:, validated_params: pagination_contract)
      end

      def build_meta(full_list:, page_meta:, originals:)
        meta = page_meta[:meta]
        meta.merge!(status_meta(full_list))
        meta.merge!(has_non_va_meds: non_va_meds?(originals))
        meta
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

      def orders
        parsed_orders = JSON.parse(request.body.read)

        # Validate that orders is an array
        raise Common::Exceptions::InvalidFieldValue.new('orders', 'Must be an array') unless parsed_orders.is_a?(Array)

        # Validate that orders array is not empty (treat empty array same as missing required parameter)
        raise Common::Exceptions::ParameterMissing, 'orders' if parsed_orders.empty?

        # Validate that each order has required fields
        parsed_orders.each_with_index do |order, index|
          unless order.is_a?(Hash) && order['stationNumber'] && order['id']
            raise Common::Exceptions::InvalidFieldValue.new(
              "orders[#{index}]",
              'Each order must contain stationNumber and id fields'
            )
          end
        end

        parsed_orders
      rescue JSON::ParserError
        raise Common::Exceptions::InvalidFieldValue.new('orders', 'Invalid JSON format')
      end
    end
  end
end
