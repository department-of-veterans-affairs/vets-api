# frozen_string_literal: true

require 'rx/client'

module Mobile
  module V0
    class PrescriptionsController < ApplicationController
      before_action { authorize :mhv_prescriptions, :access? }

      # rubocop:disable Metrics/MethodLength
      def index
        begin
          resource = client.get_history_rxs

          # Temporary logging for prescription bug investigation
          resource.attributes.each do |p|
            Rails.logger.info('MHV Prescription Response',
                              user: @current_user.uuid,
                              params: params, id: p[:prescription_id],
                              prescription: p)
          end
        rescue => e
          Rails.logger.error(
            'Mobile Prescription Upstream Index Error',
            resource: resource, error: e, message: e.message, backtrace: e.backtrace
          )
          raise e
        end

        resource = params[:filter].present? ? resource.find_by(filter_params) : resource
        resource = resource.sort(params[:sort])
        page_resource, page_meta_data = paginate(resource.attributes)

        serialized_prescription = Mobile::V0::PrescriptionsSerializer.new(page_resource, page_meta_data)

        # Temporary logging for prescription bug investigation
        serialized_prescription.to_hash[:data].each do |p|
          Rails.logger.info('Mobile Prescription Response', user: @current_user.uuid, id: p[:id], prescription: p)
        end

        render json: serialized_prescription
      end
      # rubocop:enable Metrics/MethodLength

      def refill
        resource = client.post_refill_rxs(ids)

        # Temporary logging for prescription bug investigation
        Rails.logger.info('MHV Prescription Refill Response', user: @current_user.uuid, ids: ids, response: resource)

        render json: Mobile::V0::PrescriptionsRefillsSerializer.new(@current_user.uuid, resource.body)
      rescue => e
        Rails.logger.error(
          'Mobile Prescription Refill Error',
          resource: resource, error: e, message: e.message, backtrace: e.backtrace
        )
        raise e
      end

      def tracking
        resource = client.get_tracking_history_rx(params[:id])

        # Temporary logging for prescription bug investigation
        Rails.logger.info('MHV Prescription Tracking Response', user: @current_user.uuid, id: params[:id],
                                                                response: resource)

        render json: Mobile::V0::PrescriptionTrackingSerializer.new(resource.data)
      rescue => e
        Rails.logger.error(
          'Mobile Prescription Tracking Error',
          resource: resource, error: e, message: e.message, backtrace: e.backtrace
        )
        raise e
      end

      private

      def client
        @client ||= Rx::Client.new(session: { user_id: @current_user.mhv_correlation_id }).authenticate
      end

      def pagination_params
        @pagination_params ||= Mobile::V0::Contracts::Prescriptions.new.call(
          page_number: params.dig(:page, :number),
          page_size: params.dig(:page, :size),
          filter: params[:filter].present? ? filter_params.to_h : nil,
          sort: params[:sort]
        )
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
    end
  end
end
