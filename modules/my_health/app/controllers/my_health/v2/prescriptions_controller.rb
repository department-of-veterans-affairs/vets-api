# frozen_string_literal: true

require 'unified_health_data/service'
require 'unified_health_data/serializers/prescriptions_refills_serializer'
require 'securerandom'
require 'unique_user_events'
require 'vets/collection'

module MyHealth
  module V2
    class PrescriptionsController < ApplicationController
      include Filterable
      include MyHealth::PrescriptionHelperV2::Filtering
      include MyHealth::PrescriptionHelperV2::Sorting
      include MyHealth::RxGroupingHelperV2
      include JsonApiPaginationLinks

      service_tag 'mhv-medications'

      ACTIVE_STATUSES_V1 = [
        'Active', 'Active: Refill in Process', 'Active: Non-VA', 'Active: On hold',
        'Active: Parked', 'Active: Submitted'
      ].freeze
      ACTIVE_STATUSES_V2 = ['Active'].freeze

      IN_PROGRESS_STATUSES_V1 = ['Active: Refill in Process', 'Active: Submitted'].freeze
      IN_PROGRESS_STATUSES_V2 = ['In progress'].freeze

      UNKNOWN_STATUS_V1 = 'Unknown'
      UNKNOWN_STATUS_V2 = 'Status not available'

      def refill
        return unless validate_feature_flag

        parsed_orders = orders
        result = service.refill_prescription(parsed_orders)
        response = UnifiedHealthData::Serializers::PrescriptionsRefillsSerializer.new(SecureRandom.uuid, result)

        # Log unique user event for prescription refill requested
        # Also logs OH-specific events if any facility IDs match tracked OH facilities
        event_facility_ids = parsed_orders.map { |order| order['stationNumber'] }.compact.uniq
        UniqueUserEvents.log_event(
          user: @current_user,
          event_name: UniqueUserEvents::EventRegistry::PRESCRIPTIONS_REFILL_REQUESTED,
          event_facility_ids:
        )

        render json: response.serializable_hash
      end

      # This index action supports various parameters described below, all are optional
      # @param refill_status - one refill status to filter on
      # @param page - the paginated page to fetch
      # @param per_page - the number of items to fetch per page
      # @param sort - the attribute to sort on, negated for descending, use sort[]= for multiple argument query params
      #        (ie: ?sort[]=refill_status&sort[]=-prescription_id)
      def index
        return unless validate_feature_flag

        prescriptions = service.get_prescriptions(current_only: false).compact
        recently_requested = get_recently_requested_prescriptions(prescriptions)
        raw_data = prescriptions.dup
        prescriptions = resource_data_modifications(prescriptions).compact

        filter_count = set_filter_metadata(prescriptions, raw_data)
        prescriptions, sort_metadata = apply_filters_and_sorting(prescriptions)

        records, options = build_response_data(prescriptions, filter_count, recently_requested, sort_metadata)

        log_prescriptions_access
        render json: MyHealth::V2::PrescriptionDetailsSerializer.new(records, options)
      end

      def show
        return unless validate_feature_flag

        raise Common::Exceptions::ParameterMissing, 'station_number' if params[:station_number].blank?

        prescriptions = service.get_prescriptions(current_only: false).compact
        prescription = prescriptions.find do |p|
          p.prescription_id.to_s == params[:id].to_s &&
            p.station_number.to_s == params[:station_number].to_s
        end

        raise Common::Exceptions::RecordNotFound, params[:id] unless prescription

        render json: MyHealth::V2::PrescriptionDetailsSerializer.new(prescription)
      end

      def list_refillable_prescriptions
        return unless validate_feature_flag

        prescriptions = service.get_prescriptions(current_only: false).compact
        recently_requested = get_recently_requested_prescriptions(prescriptions)
        refillable_prescriptions = filter_data_by_refill_and_renew(prescriptions)

        options = { meta: { recently_requested: } }
        render json: MyHealth::V2::PrescriptionDetailsSerializer.new(refillable_prescriptions, options)
      end

      private

      def service
        @service ||= UnifiedHealthData::Service.new(@current_user)
      end

      def validate_feature_flag
        return true if Flipper.enabled?(:mhv_medications_cerner_pilot, @current_user)

        render json: {
          error: {
            code: 'FEATURE_NOT_AVAILABLE',
            message: 'This feature is not currently available'
          }
        }, status: :forbidden
        false
      end

      def apply_filters_and_sorting(prescriptions)
        prescriptions = apply_filters_to_list(prescriptions) if params[:filter].present?
        prescriptions, sort_metadata = apply_sorting_to_list(prescriptions, params[:sort])
        [sort_prescriptions_with_pd_at_top(prescriptions), sort_metadata]
      end

      def build_response_data(prescriptions, filter_count, recently_requested, sort_metadata = {})
        is_using_pagination = params[:page].present? || params[:per_page].present?

        base_meta = filter_count.merge(recently_requested:)
        # sort_metadata is the entire metadata hash from the resource, access the :sort key
        base_meta[:sort] = sort_metadata[:sort] if sort_metadata.is_a?(Hash) && sort_metadata[:sort].present?

        if is_using_pagination
          build_paginated_response(prescriptions, base_meta)
        else
          [Array(prescriptions), { meta: base_meta }]
        end
      end

      def build_paginated_response(prescriptions, base_meta)
        collection = Vets::Collection.new(prescriptions)
        paginated = collection.paginate(
          page: pagination_params[:page],
          per_page: pagination_params[:per_page]
        )

        options = {
          meta: base_meta.merge(pagination: paginated.metadata[:pagination]),
          links: pagination_links(paginated)
        }
        [paginated.data, options]
      end

      def log_prescriptions_access
        UniqueUserEvents.log_event(
          user: @current_user,
          event_name: UniqueUserEvents::EventRegistry::PRESCRIPTIONS_ACCESSED
        )
      end

      def get_recently_requested_prescriptions(prescriptions)
        prescriptions.select do |item|
          item.respond_to?(:disp_status) && in_progress_statuses.include?(item.disp_status)
        end
      end

      def in_progress_statuses
        v2_status_mapping_enabled? ? IN_PROGRESS_STATUSES_V2 : IN_PROGRESS_STATUSES_V1
      end

      def apply_filters_to_list(prescriptions)
        filter_params = params.require(:filter).permit(disp_status: [:eq], is_trackable: [:eq], is_renewable: [:eq])
        disp_status = filter_params[:disp_status]
        is_trackable = filter_params[:is_trackable]
        is_renewable = filter_params[:is_renewable]

        prescriptions = apply_disp_status_filter(prescriptions, disp_status) if disp_status.present?
        prescriptions = apply_trackable_filter(prescriptions, is_trackable) if is_trackable.present?
        prescriptions = apply_renewable_filter(prescriptions, is_renewable) if is_renewable.present?

        prescriptions
      end

      def apply_disp_status_filter(prescriptions, disp_status)
        filters = disp_status[:eq].split(',').map(&:strip).map(&:downcase)
        prescriptions.select do |item|
          item.respond_to?(:disp_status) && item.disp_status &&
            filters.include?(item.disp_status.downcase)
        end
      end

      def apply_trackable_filter(prescriptions, is_trackable)
        filter_value = is_trackable[:eq] == 'true'
        if filter_value
          prescriptions.select { |item| shipped?(item) }
        else
          prescriptions.reject { |item| shipped?(item) }
        end
      end

      def apply_renewable_filter(prescriptions, is_renewable)
        filter_value = is_renewable[:eq] == 'true'
        if filter_value
          prescriptions.select { |item| item.respond_to?(:is_renewable) && item.is_renewable == true }
        else
          prescriptions.reject { |item| item.respond_to?(:is_renewable) && item.is_renewable == true }
        end
      end

      def shipped?(item)
        item.respond_to?(:disp_status) && item.respond_to?(:is_trackable) &&
          item.disp_status == 'Active' && item.is_trackable == true
      end

      def apply_sorting_to_list(prescriptions, sort_param)
        # Create a mock resource object for the helper methods
        resource = Struct.new(:records, :metadata).new(prescriptions, {})

        # Use the helper's apply_sorting method which sets the metadata
        sorted_resource = apply_sorting(resource, sort_param)

        [sorted_resource.records, sorted_resource.metadata]
      end

      def resource_data_modifications(prescriptions)
        display_pending_meds = Flipper.enabled?(:mhv_medications_display_pending_meds, @current_user)

        prescriptions = if params[:filter].blank? && display_pending_meds
                          prescriptions.reject do |item|
                            item.respond_to?(:prescription_source) && item.prescription_source == 'PF'
                          end
                        else
                          remove_pf_pd(prescriptions)
                        end

        group_prescriptions(prescriptions)
      end

      def set_filter_metadata(list, non_modified_collection)
        {
          filter_count: {
            all_medications: count_grouped_prescriptions(non_modified_collection),
            active: count_active_medications(list),
            in_progress: get_recently_requested_prescriptions(list).length,
            shipped: count_shipped_medications(list),
            renewable: count_renewable_medications(list),
            inactive: count_non_active_medications(list),
            transferred: count_transferred_medications(list),
            status_not_available: count_unknown_status_medications(list)
          }
        }
      end

      def count_active_medications(list)
        active_statuses = v2_status_mapping_enabled? ? ACTIVE_STATUSES_V2 : ACTIVE_STATUSES_V1
        list.count { |rx| rx.respond_to?(:disp_status) && active_statuses.include?(rx.disp_status) }
      end

      def count_non_active_medications(list)
        # When cernerPilot and v2StatusMapping flags are enabled,
        # Expired, Discontinued, and OnHold are already mapped to 'Inactive'
        list.count { |rx| rx.respond_to?(:disp_status) && rx.disp_status == 'Inactive' }
      end

      def count_shipped_medications(list)
        # Shipped: disp_status is Active AND is_trackable is true
        list.count { |rx| shipped?(rx) }
      end

      def count_renewable_medications(list)
        # Renewable: is_renewable field is true
        list.count { |rx| rx.respond_to?(:is_renewable) && rx.is_renewable == true }
      end

      def count_transferred_medications(list)
        list.count { |rx| rx.respond_to?(:disp_status) && rx.disp_status == 'Transferred' }
      end

      def count_unknown_status_medications(list)
        unknown_status = v2_status_mapping_enabled? ? UNKNOWN_STATUS_V2 : UNKNOWN_STATUS_V1
        list.count { |rx| rx.respond_to?(:disp_status) && rx.disp_status == unknown_status }
      end

      def v2_status_mapping_enabled?
        Flipper.enabled?(:mhv_medications_v2_status_mapping, @current_user)
      end

      def remove_pf_pd(data)
        sources_to_remove_from_data = %w[PF PD]
        data.reject do |item|
          item.respond_to?(:prescription_source) && sources_to_remove_from_data.include?(item.prescription_source)
        end
      end

      def sort_prescriptions_with_pd_at_top(prescriptions)
        pd_prescriptions = prescriptions.select do |med|
          med.respond_to?(:prescription_source) && med.prescription_source == 'PD'
        end
        other_prescriptions = prescriptions.reject do |med|
          med.respond_to?(:prescription_source) && med.prescription_source == 'PD'
        end

        pd_prescriptions + other_prescriptions
      end

      def orders
        @orders ||= begin
          parsed_orders = JSON.parse(request.body.read)

          # Validate that orders is an array
          unless parsed_orders.is_a?(Array)
            raise Common::Exceptions::InvalidFieldValue.new('orders',
                                                            'Must be an array')
          end

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
end
