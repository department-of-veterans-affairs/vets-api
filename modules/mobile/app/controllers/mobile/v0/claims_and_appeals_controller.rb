# frozen_string_literal: true

require_dependency 'mobile/application_controller'
require_relative '../../../models/mobile/v0/adapters/claims_overview'
require_relative '../../../models/mobile/v0/adapters/claims_overview_errors'
require_relative '../../../models/mobile/v0/claim_overview'
require 'sentry_logging'
require 'prawn'
require 'fileutils'
require 'mini_magick'

module Mobile
  module V0
    class ClaimsAndAppealsController < ApplicationController
      include IgnoreNotFound

      before_action { authorize :evss, :access? }
      after_action only: :upload_documents do
        claims_proxy.cleanup_after_upload
      end

      def index
        validated_params = validate_params(params)
        json, status = fetch_all_cached_or_service(validated_params)
        render json: json, status: status
      end

      def get_claim
        claim_detail = claims_proxy.get_claim(params[:id])
        render json: Mobile::V0::ClaimSerializer.new(claim_detail)
      end

      def get_appeal
        appeal = claims_proxy.get_appeal(params[:id])
        render json: Mobile::V0::AppealSerializer.new(appeal)
      end

      def request_decision
        jid = claims_proxy.request_decision(params[:id])
        render json: { data: { job_id: jid } }, status: :accepted
      end

      def upload_documents
        jid = claims_proxy.upload_documents(params)
        render json: { data: { job_id: jid } }, status: :accepted
      end

      private

      def fetch_all_cached_or_service(params)
        list, errors = if params[:use_cache]
                         [Mobile::V0::ClaimOverview.get_cached(@current_user), []]
                       else
                         claims_proxy.get_claims_and_appeals
                       end

        status = case errors.size
                 when 1
                   list, @pagination_meta = paginate(list, params)
                   :multi_status
                 when 2
                   :bad_gateway
                 else
                   list, @pagination_meta = paginate(list, params)
                   :ok
                 end

        options = { meta: { errors: errors, pagination: @pagination_meta } }

        [Mobile::V0::ClaimOverviewSerializer.new(list, options), status]
      end

      def claims_proxy
        @claims_proxy ||= Mobile::V0::Claims::Proxy.new(@current_user)
      end

      def validate_params(params)
        use_cache = params[:useCache] || true
        start_date = params[:startDate] || (DateTime.now.utc.beginning_of_day - 1.year).iso8601
        end_date = params[:endDate] || (DateTime.now.utc.beginning_of_day + 1.year).iso8601
        page = params[:page] || { number: 1, size: 10 }

        validated_params = Mobile::V0::Contracts::GetPaginatedList.new.call(
          start_date: start_date,
          end_date: end_date,
          page_number: page[:number],
          page_size: page[:size],
          use_cache: use_cache
        )

        raise Mobile::V0::Exceptions::ValidationErrors, validated_params if validated_params.failure?

        validated_params
      end

      def paginate(list, params)
        page_size = params[:page_size]
        page_number = params[:page_number]
        list = list.filter do |entry|
          entry[:updated_at] >= params[:start_date] && entry[:updated_at] <= params[:end_date]
        end
        total_entries = list.length
        list = list.slice(((page_number - 1) * page_size), page_size)
        [list, {
          currentPage: page_number,
          perPage: page_size,
          totalPages: (list.length / page_size.to_f).ceil,
          totalEntries: total_entries
        }]
      end
    end
  end
end
