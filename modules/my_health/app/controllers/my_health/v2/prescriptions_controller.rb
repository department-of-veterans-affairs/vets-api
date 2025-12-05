# frozen_string_literal: true

require 'unified_health_data/service'
require 'unified_health_data/serializers/prescriptions_refills_serializer'
require 'unified_health_data/adapters/v2_status_mapper'
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
      include UnifiedHealthData::Adapters::V2StatusMapper

      service_tag 'mhv-medications'

      # Add V2_STATUS_MAPPING for backward compatibility with tests
      # This provides a flat mapping from original status to V2 status
      V2_STATUS_MAPPING = V2_STATUS_GROUPS.each_with_object({}) do |(v2_status, originals), hash|
        originals.each { |original| hash[original] = v2_status }
      end.freeze

      # Delegate V2 status constants to the adapter for consistency
      # These are exposed for use in filtering and counting
      delegate :V2_STATUS_GROUPS, :ORIGINAL_TO_V2_STATUS_MAPPING, to: :status_adapter, prefix: false

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

        prescriptions = service.get_prescriptions(current_only: false, station_number: params[:station_number]).compact
        resource = find_prescription_by_id(prescriptions, params[:id])

        raise Common::Exceptions::RecordNotFound, params[:id] if resource.blank?

        # Map to V2 status when Cerner pilot is enabled
        resource = map_prescription_to_v2_status(resource) if cerner_pilot_enabled?

        options = { meta: {} }
        render json: MyHealth::V2::PrescriptionDetailsSerializer.new(resource, options)
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

        records, options = build_paginated_response(refillable_prescriptions,
                                                    { recently_requested: })
        render json: MyHealth::V2::PrescriptionDetailsSerializer.new(records, options)
      end

      private

      # Maps prescriptions to V2 statuses
      # @param prescriptions [Array] Array of prescription objects
      # @return [Array] Prescriptions with V2 status mapping applied
      def map_to_v2_statuses(prescriptions)
        apply_v2_status_mapping_to_collection(prescriptions)
      end

      # Maps a single prescription to V2 status
      # @param prescription [Object] A prescription object
      # @return [Object] Prescription with V2 status mapping applied
      def map_prescription_to_v2_status(prescription)
        apply_v2_status_mapping(prescription)
      end

      # Maps V2 filter values to original status values for filtering
      # @param filters [Array<String>] Array of V2 status values from filter params
      # @return [Array<String>] Array of original status values (lowercased)
      def map_v2_filters_to_original(filters)
        filters.flat_map do |filter|
          original_statuses = original_statuses_for_v2_status(filter)
          if original_statuses.any?
            original_statuses.map(&:downcase)
          else
            [filter.downcase]
          end
        end.uniq
      end

      # Counts medications by V2 status category
      # Includes: Active, Active: Parked, Active: Non-VA
      # @param list [Array] List of prescriptions with original status values
      # @return [Integer] Count of medications in V2 "Active" category
      def count_v2_active_medications(list)
        v2_active_originals = original_statuses_for_v2_status('Active').map(&:downcase)
        list.count do |rx|
          rx.respond_to?(:disp_status) && rx.disp_status &&
            v2_active_originals.include?(rx.disp_status.downcase)
        end
      end

      # Counts medications that will be mapped to V2 "In progress" status
      # Includes: Active: Submitted, Active: Refill in Process
      # @param list [Array] List of prescriptions with original status values
      # @return [Integer] Count of medications in V2 "In progress" category
      def count_v2_in_progress_medications(list)
        v2_in_progress_originals = original_statuses_for_v2_status('In progress').map(&:downcase)
        list.count do |rx|
          rx.respond_to?(:disp_status) && rx.disp_status &&
            v2_in_progress_originals.include?(rx.disp_status.downcase)
        end
      end

      # Counts medications that will be mapped to V2 "Inactive" status
      # Includes: Expired, Discontinued, Active: On hold
      # Also includes Transferred and Unknown as non-active statuses
      # @param list [Array] List of prescriptions with original status values
      # @return [Integer] Count of medications in V2 "Inactive" category
      def count_v2_inactive_medications(list)
        inactive_statuses = original_statuses_for_v2_status('Inactive')
        transferred_statuses = original_statuses_for_v2_status('Transferred')
        unknown_statuses = original_statuses_for_v2_status('Status not available')

        non_active_originals = (inactive_statuses + transferred_statuses + unknown_statuses).map(&:downcase)
        list.count do |rx|
          rx.respond_to?(:disp_status) && rx.disp_status &&
            non_active_originals.include?(rx.disp_status.downcase)
        end
      end

      # Gets recently requested prescriptions (V2 "In progress" status)
      # NOTE: Called BEFORE V2 mapping, checks for original status values
      # Original statuses: "Active: Submitted", "Active: Refill in Process"
      # @param prescriptions [Array] List of prescriptions with original status values
      # @return [Array] Prescriptions that map to V2 "In progress" status
      def get_recently_requested_prescriptions(prescriptions)
        v2_in_progress_originals = original_statuses_for_v2_status('In progress').map(&:downcase)
        prescriptions.select do |item|
          item.respond_to?(:disp_status) && item.disp_status &&
            v2_in_progress_originals.include?(item.disp_status.downcase)
        end
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

      def cerner_pilot_enabled?
        Flipper.enabled?(:mhv_medications_cerner_pilot, @current_user)
      end

      def service
        @service ||= UnifiedHealthData::Service.new(@current_user)
      end

      def orders
        @orders ||= begin
          raw_orders = params.require(:orders)
          unless raw_orders.is_a?(Array)
            raise Common::Exceptions::InvalidFieldValue.new('orders', 'Expected an array of order objects')
          end

          parsed_orders = raw_orders.map do |order|
            order = order.permit(:stationNumber, :id) if order.respond_to?(:permit)
            { station_number: order[:stationNumber] || order['stationNumber'], id: order[:id] || order['id'] }
          end

          parsed_orders
        rescue JSON::ParserError
          raise Common::Exceptions::InvalidFieldValue.new('orders', 'Invalid JSON format')
        end
      end

      def pagination_params
        {
          page: params[:page]&.to_i || 1,
          per_page: params[:per_page]&.to_i || 10
        }
      end

      def apply_filters_and_sorting(prescriptions)
        prescriptions = apply_filters_to_list(prescriptions) if params[:filter].present?
        sorted = apply_sorting_to_list(prescriptions)
        sort_metadata = build_sort_metadata(params[:sort])
        [sorted, sort_metadata]
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

      def apply_sorting_to_list(prescriptions)
        sort_param = params[:sort]
        return prescriptions if sort_param.blank?

        sort_fields = sort_param.is_a?(Array) ? sort_param : [sort_param]
        prescriptions.sort do |a, b|
          compare_by_fields(a, b, sort_fields)
        end
      end

      def compare_by_fields(item_a, item_b, sort_fields)
        sort_fields.each do |field|
          descending = field.start_with?('-')
          field_name = descending ? field[1..] : field
          comparison = compare_field_values(item_a, item_b, field_name)
          comparison = -comparison if descending
          return comparison unless comparison.zero?
        end
        0
      end

      def compare_field_values(item_a, item_b, field_name)
        value_a = item_a.respond_to?(field_name) ? item_a.send(field_name) : nil
        value_b = item_b.respond_to?(field_name) ? item_b.send(field_name) : nil
        (value_a || '') <=> (value_b || '')
      end

      def build_sort_metadata(sort_param)
        return {} if sort_param.blank?

        { sort: sort_param }
      end

      def find_prescription_by_id(prescriptions, id)
        prescriptions.find { |p| p.prescription_id.to_s == id.to_s }
      end

      def resource_data_modifications(prescriptions)
        remove_pf_pd(prescriptions)
      end

      def build_response_data(prescriptions, filter_count, recently_requested, sort_metadata)
        paginated = collection_resource(prescriptions).paginate(
          page: pagination_params[:page],
          per_page: pagination_params[:per_page]
        )

        options = {
          meta: filter_count.merge(pagination: paginated.metadata[:pagination])
                            .merge(sort_metadata)
                            .merge(recently_requested:),
          links: pagination_links(paginated)
        }
        [paginated.data, options]
      end

      def build_paginated_response(prescriptions, base_meta)
        collection = collection_resource(prescriptions)
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
        pd_prescriptions = prescriptions.select { |rx| rx.prescription_source == 'PD' }
        other_prescriptions = prescriptions.reject { |rx| rx.prescription_source == 'PD' }

        pd_prescriptions + other_prescriptions
      end

      def collection_resource(prescriptions = nil)
        Vets::Collection.new(prescriptions || [])
      end
    end
  endend
  