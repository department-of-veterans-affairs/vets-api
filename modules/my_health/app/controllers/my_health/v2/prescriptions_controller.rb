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

      # Include V2StatusMapper to get access to V2_STATUS_GROUPS and ORIGINAL_TO_V2_STATUS_MAPPING constants
      include UnifiedHealthData::Adapters::V2StatusMapper

      before_action :validate_feature_flag

      # Add V2_STATUS_MAPPING for backward compatibility with tests
      # This provides a flat mapping from original status to V2 status
      V2_STATUS_MAPPING = V2_STATUS_GROUPS.each_with_object({}) do |(v2_status, originals), hash|
        originals.each { |original| hash[original] = v2_status }
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

        # Service returns prescriptions with V2 status mapping already applied
        prescriptions = service.get_prescriptions(current_only: false).compact

        # Grouping and other modifications (status mapping already done)
        prescriptions = resource_data_modifications(prescriptions).compact

        # No need to call apply_v2_status_mapping here - already done in adapter

        recently_requested = get_recently_requested_prescriptions(prescriptions)
        filter_count = set_filter_metadata(prescriptions, prescriptions)

        prescriptions, sort_metadata = apply_filters_and_sorting(prescriptions)
        records, options = build_response_data(prescriptions, filter_count, recently_requested, sort_metadata)

        render json: serializer_class.new(records, options)
      end

      def show
        return unless validate_feature_flag

        prescriptions = service.get_prescriptions(current_only: false, station_number: params[:station_number]).compact
        resource = find_prescription_by_id(prescriptions, params[:id])

        raise Common::Exceptions::RecordNotFound, params[:id] if resource.blank?

        options = { meta: {} }
        render json: MyHealth::V2::PrescriptionDetailsSerializer.new(resource, options)
      end

      def list_refillable_prescriptions
        return unless validate_feature_flag

        # Service returns prescriptions with V2 status mapping already applied when cerner_pilot is enabled
        prescriptions = service.get_prescriptions(current_only: false).compact
        recently_requested = get_recently_requested_prescriptions(prescriptions)
        refillable_prescriptions = filter_data_by_refill_and_renew(prescriptions)

        # V2 status mapping is handled by the service when cerner_pilot feature flag is enabled

        records, options = build_paginated_response(refillable_prescriptions,
                                                    { recently_requested: })
        render json: MyHealth::V2::PrescriptionDetailsSerializer.new(records, options)
      end

      private

      # V2 status mapping is controlled by the cerner_pilot feature flag.
      # When enabled, prescriptions display simplified V2 statuses (Active, In progress, Inactive, etc.)
      # instead of the original granular statuses (Active: Refill in Process, Expired, etc.)
      def cerner_pilot_enabled?
        Flipper.enabled?(:mhv_medications_display_cerner_pilot, @current_user)
      end

      def service
        # V2 controller uses V2 statuses when cerner_pilot feature flag is enabled
        @service ||= UnifiedHealthData::Service.new(@current_user, use_v2_statuses: cerner_pilot_enabled?)
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

        return prescriptions if disp_status.blank?

        if renewal_filter?(disp_status[:eq])
          prescriptions.select(&method(:renewable))
        else
          filter_by_disp_status(prescriptions, disp_status[:eq])
        end
      end

      def renewal_filter?(filter_value)
        normalized = filter_value&.downcase
        ['active,expired', 'active,inactive'].include?(normalized)
      end

      def filter_by_disp_status(prescriptions, filter_value)
        expanded_filters = expand_status_filters(filter_value)

        prescriptions.select do |item|
          item.respond_to?(:disp_status) && item.disp_status &&
            expanded_filters.any? { |f| item.disp_status.casecmp(f).zero? }
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
            active: count_by_status(list, 'Active'),
            in_progress: count_by_status(list, 'In progress'),
            shipped: count_shipped_prescriptions(list),
            renewal: list.count { |item| renewable(item) },
            inactive: count_by_status(list, 'Inactive'),
            transferred: count_by_status(list, 'Transferred'),
            unknown: count_by_status(list, ['Unknown', 'Status not available'])
          }
        }
      end

      def count_by_status(prescriptions, statuses)
        statuses = Array(statuses)
        prescriptions.count do |item|
          item.respond_to?(:disp_status) && item.disp_status &&
            statuses.any? { |s| item.disp_status.casecmp(s).zero? }
        end
      end

      def count_shipped_prescriptions(prescriptions)
        prescriptions.count do |item|
          active_status?(item) && trackable?(item)
        end
      end

      def active_status?(item)
        item.respond_to?(:disp_status) && item.disp_status&.casecmp('Active')&.zero?
      end

      def trackable?(item)
        item.respond_to?(:is_trackable) && item.is_trackable == true
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
  end
end
