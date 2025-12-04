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

      # V2 Status Categories - Single source of truth for status groupings
      # Each V2 status maps to an array of original MHV statuses
      V2_STATUS_GROUPS = {
        'Active' => ['Active', 'Active: Parked', 'Active: Non-VA'].freeze,
        'In progress' => ['Active: Submitted', 'Active: Refill in Process'].freeze,
        'Inactive' => ['Expired', 'Discontinued', 'Active: On hold'].freeze,
        'Transferred' => ['Transferred'].freeze,
        'Status not available' => ['Unknown'].freeze
      }.freeze

      # Generated mapping from original status to V2 status (case-insensitive lookup)
      # Example: { 'active' => 'Active', 'active: parked' => 'Active', ... }
      ORIGINAL_TO_V2_STATUS_MAPPING = V2_STATUS_GROUPS.each_with_object({}) do |(v2_status, originals), hash|
        originals.each { |original| hash[original.downcase] = v2_status }
      end.freeze

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

        # Case-insensitive lookup
        new_status = ORIGINAL_TO_V2_STATUS_MAPPING[prescription.disp_status.downcase]

        prescription.disp_status = new_status if new_status && prescription.respond_to?(:disp_status=)

        prescription
      end

      # Counts medications by V2 status category
      # @param list [Array] List of prescriptions with original status values
      # @param v2_status [String] The V2 status category to count
      # @return [Integer] Count of medications matching the V2 category
      def count_medications_by_v2_status(list, v2_status)
        original_statuses = V2_STATUS_GROUPS[v2_status]&.map(&:downcase) || []
        list.count do |rx|
          rx.respond_to?(:disp_status) && rx.disp_status &&
            original_statuses.include?(rx.disp_status.downcase)
        end
      end

      def count_v2_active_medications(list)
        count_medications_by_v2_status(list, 'Active')
      end

      def count_v2_in_progress_medications(list)
        count_medications_by_v2_status(list, 'In progress')
      end

      def count_v2_inactive_medications(list)
        # Inactive includes Transferred and Status not available for non_active count
        non_active_v2_statuses = ['Inactive', 'Transferred', 'Status not available']
        non_active_v2_statuses.sum { |status| count_medications_by_v2_status(list, status) }
      end

      # Gets recently requested prescriptions (V2 "In progress" status)
      # NOTE: Called BEFORE V2 mapping, checks for original status values
      # Original statuses: "Active: Submitted", "Active: Refill in Process"
      # @param prescriptions [Array] List of prescriptions with original status values
      # @return [Array] Prescriptions that map to V2 "In progress" status
      def get_recently_requested_prescriptions(prescriptions)
        in_progress_originals = V2_STATUS_GROUPS['In progress'].map(&:downcase)
        prescriptions.select do |item|
          item.respond_to?(:disp_status) && item.disp_status &&
            in_progress_originals.include?(item.disp_status.downcase)
        end
      end

      # Maps V2 filter values to original status values for filtering
      # @param filters [Array<String>] Array of V2 status values from filter params
      # @return [Array<String>] Array of original status values (lowercased)
      def map_v2_filters_to_original(filters)
        filters.flat_map do |filter|
          original_statuses = V2_STATUS_GROUPS[filter]
          if original_statuses
            original_statuses.map(&:downcase)
          else
            # If no mapping found, use the filter value as-is (backwards compatibility)
            [filter.downcase]
          end
        end.uniq
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
