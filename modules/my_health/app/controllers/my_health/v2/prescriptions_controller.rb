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
      include MyHealth::PrescriptionHelper::Filtering
      include MyHealth::RxGroupingHelper
      include JsonApiPaginationLinks

      service_tag 'mhv-prescriptions'

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
        prescriptions = apply_filters_and_sorting(prescriptions)

        records, options = build_response_data(prescriptions, filter_count, recently_requested)

        log_prescriptions_access
        render json: MyHealth::V2::PrescriptionDetailsSerializer.new(records, options)
      end

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
        prescriptions = apply_sorting_to_list(prescriptions, params[:sort])
        sort_prescriptions_with_pd_at_top(prescriptions)
      end

      def build_response_data(prescriptions, filter_count, recently_requested)
        is_using_pagination = params[:page].present? || params[:per_page].present?

        if is_using_pagination
          build_paginated_response(prescriptions, filter_count, recently_requested)
        else
          [Array(prescriptions), { meta: filter_count.merge(recently_requested:) }]
        end
      end

      def build_paginated_response(prescriptions, filter_count, recently_requested)
        collection = Vets::Collection.new(prescriptions)
        paginated = collection.paginate(
          page: pagination_params[:page],
          per_page: pagination_params[:per_page]
        )

        options = {
          meta: filter_count.merge(
            recently_requested:,
            pagination: paginated.metadata[:pagination]
          ),
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
          item.respond_to?(:disp_status) && ['Active: Refill in Process',
                                             'Active: Submitted'].include?(item.disp_status)
        end
      end

      def apply_filters_to_list(prescriptions)
        filter_params = params.require(:filter).permit(:disp_status)
        disp_status = filter_params[:disp_status]

        if disp_status.present?
          if disp_status[:eq]&.downcase == 'active,expired'.downcase
            filter_renewals(prescriptions)
          else
            filters = disp_status[:eq].split(',').map(&:strip).map(&:downcase)
            prescriptions.select do |item|
              item.respond_to?(:disp_status) && filters.include?(item.disp_status.downcase)
            end
          end
        else
          prescriptions
        end
      end

      def filter_renewals(prescriptions)
        prescriptions.select(&method(:renewable))
      end

      def apply_sorting_to_list(prescriptions, sort_param)
        case sort_param
        when 'last-fill-date'
          last_fill_date_sort(prescriptions)
        when 'alphabetical-rx-name'
          alphabetical_sort(prescriptions)
        else
          default_sort(prescriptions)
        end
      end

      def default_sort(prescriptions)
        prescriptions.sort do |a, b|
          # 1st sort by status
          a_status = a.respond_to?(:disp_status) ? (a.disp_status || '') : ''
          b_status = b.respond_to?(:disp_status) ? (b.disp_status || '') : ''
          status_comparison = a_status <=> b_status
          next status_comparison if status_comparison != 0

          # 2nd sort by medication name
          a_name = a.respond_to?(:prescription_name) ? (a.prescription_name || '') : ''
          b_name = b.respond_to?(:prescription_name) ? (b.prescription_name || '') : ''
          name_comparison = a_name <=> b_name
          next name_comparison if name_comparison != 0

          # 3rd sort by fill date - newest to oldest
          a_date = a.respond_to?(:sorted_dispensed_date) ? a.sorted_dispensed_date : nil
          b_date = b.respond_to?(:sorted_dispensed_date) ? b.sorted_dispensed_date : nil
          a_date ||= Date.new(1900, 1, 1)
          b_date ||= Date.new(1900, 1, 1)

          b_date <=> a_date
        end
      end

      def last_fill_date_sort(prescriptions)
        empty_dispense_date_meds, filled_meds = partition_meds_by_date(prescriptions)

        filled_meds = filled_meds.sort_by do |med|
          date = med.respond_to?(:sorted_dispensed_date) ? med.sorted_dispensed_date : Date.new(1900, 1, 1)
          name = med.respond_to?(:prescription_name) ? med.prescription_name.to_s.downcase : ''
          [-date&.to_time.to_i, name]
        end

        non_va_meds = empty_dispense_date_meds.select do |med|
          med.respond_to?(:prescription_source) && med.prescription_source == 'NV'
        end
        va_meds = empty_dispense_date_meds.reject do |med|
          med.respond_to?(:prescription_source) && med.prescription_source == 'NV'
        end

        non_va_meds.sort_by! { |med| med.respond_to?(:prescription_name) ? med.prescription_name.to_s.downcase : '' }
        va_meds.sort_by! { |med| med.respond_to?(:prescription_name) ? med.prescription_name.to_s.downcase : '' }

        filled_meds + va_meds + non_va_meds
      end

      def alphabetical_sort(prescriptions)
        sorted_records = prescriptions.sort_by { |med| get_medication_name(med) }

        sorted_records.group_by { |med| get_medication_name(med) }.flat_map do |_name, meds|
          empty_dates, with_dates = meds.partition do |med|
            empty_field?(med.respond_to?(:sorted_dispensed_date) ? med.sorted_dispensed_date : nil)
          end
          sorted_with_dates = with_dates.sort_by { |med| -med.sorted_dispensed_date&.to_time.to_i }
          empty_dates + sorted_with_dates
        end
      end

      def partition_meds_by_date(prescriptions)
        empty_dispense_date_meds = []
        filled_meds = []

        prescriptions.each do |med|
          date = med.respond_to?(:sorted_dispensed_date) ? med.sorted_dispensed_date : nil
          if empty_field?(date)
            empty_dispense_date_meds << med
          else
            filled_meds << med
          end
        end

        [empty_dispense_date_meds, filled_meds]
      end

      def get_medication_name(med)
        if med.respond_to?(:disp_status) && med.disp_status == 'Active: Non-VA' &&
           (!med.respond_to?(:prescription_name) || med.prescription_name.nil?)
          med.respond_to?(:orderable_item) ? (med.orderable_item || '') : ''
        else
          med.respond_to?(:prescription_name) ? (med.prescription_name || '') : ''
        end
      end

      def empty_field?(value)
        value.nil? || value.to_s.strip.empty?
      end

      def resource_data_modifications(prescriptions)
        display_pending_meds = Flipper.enabled?(:mhv_medications_display_pending_meds, @current_user)

        if params[:filter].blank? && display_pending_meds
          prescriptions.reject do |item|
            item.respond_to?(:prescription_source) && item.prescription_source == 'PF'
          end
        else
          remove_pf_pd(prescriptions)
        end

        # NOTE: Grouping is handled at the adapter level for VistA prescriptions
        # (see vista_prescription_adapter.rb which parses RF records into grouped_medications).
        # UHD prescriptions cannot be grouped here because they lack prescription numbers,
        # which are required for matching related prescriptions and renewals.
      end

      def set_filter_metadata(list, non_modified_collection)
        {
          filter_count: {
            all_medications: count_grouped_prescriptions(non_modified_collection),
            active: count_active_medications(list),
            recently_requested: get_recently_requested_prescriptions(list).length,
            renewal: list.select { |item| renewable(item) }.length,
            non_active: count_non_active_medications(list)
          }
        }
      end

      def count_active_medications(list)
        active_statuses = [
          'Active', 'Active: Refill in Process', 'Active: Non-VA', 'Active: On hold',
          'Active: Parked', 'Active: Submitted'
        ]
        list.count { |rx| rx.respond_to?(:disp_status) && active_statuses.include?(rx.disp_status) }
      end

      def count_non_active_medications(list)
        non_active_statuses = %w[Discontinued Expired Transferred Unknown]
        list.count { |rx| rx.respond_to?(:disp_status) && non_active_statuses.include?(rx.disp_status) }
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
