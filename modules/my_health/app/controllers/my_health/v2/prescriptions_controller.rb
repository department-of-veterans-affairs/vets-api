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

      # Mapping from current VA.gov statuses to new VA.gov V2 statuses
      # Only applied when mhv_medications_cerner_pilot feature flag is enabled
      V2_STATUS_MAPPING = {
        'Active' => 'Active',
        'Active: Parked' => 'Active',
        'Active: Non-VA' => 'Active',
        'Active: Submitted' => 'In progress',
        'Active: Refill in Process' => 'In progress',
        'Expired' => 'Inactive',
        'Discontinued' => 'Inactive',
        'Active: On hold' => 'Inactive',
        'Transferred' => 'Transferred',
        'Unknown' => 'Status not available'
      }.freeze

      # Reverse mapping from V2 statuses to original statuses for filtering
      # Used when cerner_pilot is enabled to translate filter values
      V2_TO_ORIGINAL_STATUS_MAPPING = {
        'Active' => ['Active', 'Active: Parked', 'Active: Non-VA'],
        'In progress' => ['Active: Submitted', 'Active: Refill in Process'],
        'Inactive' => ['Expired', 'Discontinued', 'Active: On hold'],
        'Transferred' => ['Transferred'],
        'Status not available' => ['Unknown']
      }.freeze

      # Original statuses that map to V2 "Active" for counting purposes
      V2_ACTIVE_STATUSES = ['Active', 'Active: Parked', 'Active: Non-VA'].freeze

      # Original statuses that map to V2 "In progress" for counting purposes
      V2_IN_PROGRESS_STATUSES = ['Active: Submitted', 'Active: Refill in Process'].freeze

      # Original statuses that map to V2 "Inactive" for counting purposes
      V2_INACTIVE_STATUSES = ['Expired', 'Discontinued', 'Active: On hold'].freeze

      def refill
        return unless validate_feature_flag

        result = service.refill_prescription(orders)
        response = UnifiedHealthData::Serializers::PrescriptionsRefillsSerializer.new(SecureRandom.uuid, result)

        # Log unique user event for prescription refill requested
        UniqueUserEvents.log_event(
          user: @current_user,
          event_name: UniqueUserEvents::EventRegistry::PRESCRIPTIONS_REFILL_REQUESTED
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

        # Map to V2 statuses when Cerner pilot is enabled
        if cerner_pilot_enabled?
          prescriptions = map_to_v2_statuses(prescriptions)
          recently_requested = map_to_v2_statuses(recently_requested)
        end

        records, options = build_response_data(prescriptions, filter_count, recently_requested, sort_metadata)

        log_prescriptions_access
        render json: MyHealth::V2::PrescriptionDetailsSerializer.new(records, options)
      end

      def show
        return unless validate_feature_flag

        prescriptions = service.get_prescriptions(current_only: false).compact
        prescription = prescriptions.find do |p|
          p.prescription_id.to_s == params[:id].to_s &&
            p.station_number.to_s == params[:station_number].to_s
        end

        raise Common::Exceptions::RecordNotFound, params[:id] unless prescription

        # Map to V2 status when Cerner pilot is enabled
        prescription = map_prescription_to_v2_status(prescription) if cerner_pilot_enabled?

        render json: MyHealth::V2::PrescriptionDetailsSerializer.new(prescription)
      end

      def list_refillable_prescriptions
        return unless validate_feature_flag

        prescriptions = service.get_prescriptions(current_only: false).compact
        recently_requested = get_recently_requested_prescriptions(prescriptions)
        refillable_prescriptions = filter_data_by_refill_and_renew(prescriptions)

        # Map to V2 statuses when Cerner pilot is enabled
        if cerner_pilot_enabled?
          refillable_prescriptions = map_to_v2_statuses(refillable_prescriptions)
          recently_requested = map_to_v2_statuses(recently_requested)
        end

        options = { meta: { recently_requested: } }
        render json: MyHealth::V2::PrescriptionDetailsSerializer.new(refillable_prescriptions, options)
      end

      private

      def service
        @service ||= UnifiedHealthData::Service.new(@current_user)
      end

      def cerner_pilot_enabled?
        Flipper.enabled?(:mhv_medications_cerner_pilot, @current_user)
      end

      def validate_feature_flag
        return true if cerner_pilot_enabled?

        render json: {
          error: {
            code: 'FEATURE_NOT_AVAILABLE',
            message: 'This feature is not currently available'
          }
        }, status: :forbidden
        false
      end

      # Maps a collection of prescriptions to V2 statuses
      # @param prescriptions [Array] Array of prescription objects
      # @return [Array] Prescriptions with disp_status mapped to V2 values
      def map_to_v2_statuses(prescriptions)
        prescriptions.map { |prescription| map_prescription_to_v2_status(prescription) }
      end

      # Maps a single prescription's disp_status to V2 status
      # @param prescription [Object] A prescription object
      # @return [Object] Prescription with disp_status mapped to V2 value
      def map_prescription_to_v2_status(prescription)
        return prescription unless prescription.respond_to?(:disp_status) && prescription.disp_status.present?

        new_status = V2_STATUS_MAPPING[prescription.disp_status]

        # Only update if we have a mapping for this status
        if new_status && new_status != prescription.disp_status && prescription.respond_to?(:disp_status=)
          prescription.disp_status = new_status
        end

        prescription
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

      def set_filter_metadata(list, non_modified_collection)
        {
          filter_count: {
            all_medications: count_grouped_prescriptions(non_modified_collection),
            active: count_v2_active_medications(list),
            recently_requested: count_v2_in_progress_medications(list),
            renewal: list.count { |item| renewable(item) },
            non_active: count_v2_inactive_medications(list)
          }
        }
      end

      def count_v2_active_medications(list)
        list.count do |rx|
          rx.respond_to?(:disp_status) && V2_ACTIVE_STATUSES.include?(rx.disp_status)
        end
      end

      def count_v2_in_progress_medications(list)
        list.count do |rx|
          rx.respond_to?(:disp_status) && V2_IN_PROGRESS_STATUSES.include?(rx.disp_status)
        end
      end

      def count_v2_inactive_medications(list)
        non_active_original_statuses = V2_INACTIVE_STATUSES + %w[Transferred Unknown]
        list.count do |rx|
          rx.respond_to?(:disp_status) && non_active_original_statuses.include?(rx.disp_status)
        end
      end

      def get_recently_requested_prescriptions(prescriptions)
        prescriptions.select do |item|
          item.respond_to?(:disp_status) && V2_IN_PROGRESS_STATUSES.include?(item.disp_status)
        end
      end

      def apply_filters_to_list(prescriptions)
        filter_params = params.require(:filter).permit(disp_status: [:eq])
        disp_status = filter_params[:disp_status]

        if disp_status.present?
          if disp_status[:eq]&.downcase == 'active,expired'.downcase
            # filter renewals
            prescriptions.select(&method(:renewable))
          else
            filters = disp_status[:eq].split(',').map(&:strip)
            # Map V2 filter values to original status values for filtering
            # V2 controller always has cerner_pilot enabled (enforced by validate_feature_flag)
            original_filters = map_v2_filters_to_original(filters)

            prescriptions.select do |item|
              item.respond_to?(:disp_status) && item.disp_status &&
                original_filters.include?(item.disp_status.downcase)
            end
          end
        else
          prescriptions
        end
      end

      def map_v2_filters_to_original(filters)
        filters.flat_map do |filter|
          original_statuses = V2_TO_ORIGINAL_STATUS_MAPPING[filter]
          if original_statuses
            original_statuses.map(&:downcase)
          else
            # If no mapping found, use the filter value as-is (for backwards compatibility)
            [filter.downcase]
          end
        end.uniq
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

      def count_grouped_prescriptions(prescriptions)
        # Group by station number and prescription ID, count unique combinations
        prescriptions.group_by { |rx| [rx.station_number, rx.prescription_id] }.count
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
