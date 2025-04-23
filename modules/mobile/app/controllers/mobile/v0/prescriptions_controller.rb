# frozen_string_literal: true

require 'rx/client'

module Mobile
  module V0
    class PrescriptionsController < ApplicationController
      before_action { authorize :mhv_prescriptions, :access? }

      def index
        resource = client.get_all_rxs
        resource.data = resource_data_modifications(resource)
        resource = resource.find_by(filter_params) if params[:filter].present?
        resource = resource.sort(params[:sort])
        page_resource, page_meta_data = paginate(resource.attributes)

        page_meta_data[:meta].merge!(status_meta(resource))

        render json: Mobile::V0::PrescriptionsSerializer.new(page_resource, page_meta_data)
      end

      def refill
        resource = client.post_refill_rxs(ids)

        render json: Mobile::V0::PrescriptionsRefillsSerializer.new(@current_user.uuid, resource.body)
      end

      def tracking
        resource = client.get_tracking_history_rx(params[:id])

        render json: Mobile::V0::PrescriptionTrackingSerializer.new(resource.data)
      end

      private

      def client
        @client ||= Rx::Client.new(
          session: { user_id: @current_user.mhv_correlation_id }, upstream_request: request
        ).authenticate
      end

      def pagination_params
        @pagination_params ||= Mobile::V0::Contracts::Prescriptions.new.call(
          page_number: params.dig(:page, :number),
          page_size: params.dig(:page, :size),
          filter: params[:filter].present? ? filter_params.to_h : nil,
          sort: params[:sort]
        )
      end

      def status_meta(resource)
        {
          prescription_status_count: resource.attributes.each_with_object(Hash.new(0)) do |obj, hash|
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

      def paginate(records)
        Mobile::PaginationHelper.paginate(list: records, validated_params: pagination_params)
      end

      def filter_params
        @filter_params ||= begin
          valid_filter_params = params.require(:filter).permit(Prescription.filterable_attributes)
          raise Common::Exceptions::FilterNotAllowed, params[:filter] if valid_filter_params.empty?

          valid_filter_params
        end
      end

      def ids
        ids = params.require(:ids)
        raise Common::Exceptions::InvalidFieldValue.new('ids', ids) unless ids.is_a? Array

        ids.map(&:to_i)
      end

      def resource_data_modifications(resource)
        # Remove Partial Fill (PF) and/or Pending Pescriptions (PD)
        display_pending_meds = Flipper.enabled?(:mhv_medications_display_pending_meds, current_user)
        resource.data = if params[:filter].blank? && display_pending_meds
                          resource.data.reject { |item| item.prescription_source.equal? 'PF' }
                        else
                          # TODO: remove this line when PF and PD are allowed on the app
                          resource.data = remove_pf_pd(resource.data)
                        end

        # Remove Non-VA (NV) medications
        # TODO: Update once active Non-VA meds have been whitelisted for the app
        resource.data = resource.data.reject { |item| item[:prescription_source] == 'NV' }

        # Remove discontinued/expired medications that are older than 180 days
        resource.data = remove_old_meds(resource.data)

        resource.data.each do |r|
          r[:prescription_name] = r[:orderable_item] if r[:prescription_name].nil?
        end
      end

      def remove_pf_pd(data)
        sources_to_remove_from_data = %w[PF PD]
        data.reject { |item| sources_to_remove_from_data.include?(item.prescription_source) }
      end

      def remove_old_meds(data)
        status_with_date_limit = %w[discontinued expired]
        data.reject do |item|
          status_with_date_limit.include?(item.refill_status) && item.expiration_date < 180.days.ago
        end
      end
    end
  end
end
