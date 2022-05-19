# frozen_string_literal: true

require 'rx/client'

module Mobile
  module V0
    class PrescriptionsController < ApplicationController
      include Filterable

      before_action { authorize :mhv_prescriptions, :access? }

      DEFAULT_PAGE_NUMBER = 1
      DEFAULT_PAGE_SIZE = 10

      def index
        resource = client.get_history_rxs
        resource = params[:filter].present? ? resource.find_by(filter_params) : resource
        resource = resource.sort(params[:sort])
        page_resource, page_meta_data = paginate(resource.attributes)

        render json: Mobile::V0::PrescriptionsSerializer.new(page_resource, page_meta_data)
      end

      private

      def client
        @client ||= Rx::Client.new(session: { user_id: @current_user.mhv_correlation_id })
      end

      def pagination_params
        @pagination_params ||= Mobile::V0::Contracts::GetPaginatedList.new.call(
          page_number: params.dig(:page, :number) || DEFAULT_PAGE_NUMBER,
          page_size: params.dig(:page, :size) || DEFAULT_PAGE_SIZE
        )
      end

      def paginate(records)
        url = request.base_url + request.path
        page_records, page_meta_data = Mobile::PaginationHelper.paginate(
          list: records, validated_params: pagination_params, url: url
        )

        # this is temporary. this has come up multiple times and we should develop a better solution
        page_meta_data[:links].transform_values! do |link|
          next if link.nil?

          if params[:filter].present?
            filter_hash = filter_params.to_h
            filter_field = filter_hash.keys.first
            filter_operator = filter_hash.values.first.keys.first
            filter_value = filter_hash.values.first.values.first

            link += "&filter[[#{filter_field}][#{filter_operator}]]=#{filter_value}"
          end

          link += "&sort=#{params['sort']}" if params[:sort].present?

          link
        end

        [page_records, page_meta_data]
      end

      def filter_params
        valid_filter_params = params.require(:filter).permit(Prescription.filterable_attributes)
        raise Common::Exceptions::FilterNotAllowed, params['filter'] if valid_filter_params.empty?

        valid_filter_params
      end
    end
  end
end
