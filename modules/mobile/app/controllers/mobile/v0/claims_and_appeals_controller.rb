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
                   :multi_status
                 when 2
                   :bad_gateway
                 else
                   :ok
                 end

        list, pagination_meta, links_meta = paginate(list, params)
        options = { meta: { errors: errors, pagination: pagination_meta }, links: links_meta }

        [Mobile::V0::ClaimOverviewSerializer.new(list, options), status]
      end

      def claims_proxy
        @claims_proxy ||= Mobile::V0::Claims::Proxy.new(@current_user)
      end

      def validate_params(params)
        params = fill_missing_params(params)
        validated_params = Mobile::V0::Contracts::GetPaginatedList.new.call(
          start_date: params[0],
          end_date: params[1],
          page_number: params[2][:number],
          page_size: params[2][:size],
          use_cache: params[3]
        )

        raise Mobile::V0::Exceptions::ValidationErrors, validated_params if validated_params.failure?

        validated_params
      end

      def fill_missing_params(params)
        [
          params[:startDate] || (DateTime.now.utc.beginning_of_day - 1.year).iso8601,
          params[:endDate] || (DateTime.now.utc.beginning_of_day + 1.year).iso8601,
          params[:page] || { number: 1, size: 10 },
          params[:useCache] || true
        ]
      end

      def paginate(list, params)
        page_size = params[:page_size]
        page_number = params[:page_number]
        list = list.filter do |entry|
          entry[:updated_at] >= params[:start_date] && entry[:updated_at] <= params[:end_date]
        end
        total_entries = list.length
        list = list.slice(((page_number - 1) * page_size), page_size)
        total_pages = (total_entries / page_size.to_f).ceil
        [list,
         {
          currentPage: page_number,
          perPage: page_size,
          totalPages: total_pages,
          totalEntries: total_entries
        },
         links(total_pages, params)]
      end

      def links(number_of_pages, validated_params)
        page_number = validated_params[:page_number]
        page_size = validated_params[:page_size]

        query_string = "?startDate=#{validated_params[:start_date]}&endDate=#{validated_params[:end_date]}"\
          "&useCache=#{validated_params[:use_cache]}"
        url = request.base_url + request.path + query_string

        if page_number > 1
          prev_link = "#{url}&page[number]=#{[page_number - 1,
                                              number_of_pages].min}&page[size]=#{page_size}"
        end

        if page_number < number_of_pages
          next_link = "#{url}&page[number]=#{[page_number + 1,
                                              number_of_pages].min}&page[size]=#{page_size}"
        end

        {
            self: "#{url}&page[number]=#{page_number}&page[size]=#{page_size}",
            first: "#{url}&page[number]=1&page[size]=#{page_size}",
            prev: prev_link,
            next: next_link,
            last: "#{url}&page[number]=#{number_of_pages}&page[size]=#{page_size}"
        }
      end
    end
  end
end
