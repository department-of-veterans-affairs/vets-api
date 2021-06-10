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
      after_action only: :upload_multi_image_document do
        claims_proxy.cleanup_after_upload
      end

      def index
        validated_params = validate_params(params)

        json, status = fetch_all_cached_or_service(validated_params, params[:showCompleted])
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

      def upload_document
        jid = claims_proxy.upload_document(params)
        render json: { data: { job_id: jid } }, status: :accepted
      end

      def upload_multi_image_document
        jid = claims_proxy.upload_multi_image(params)
        render json: { data: { job_id: jid } }, status: :accepted
      end

      private

      def fetch_all_cached_or_service(params, show_completed)
        list = nil
        list = Mobile::V0::ClaimOverview.get_cached(@current_user) if params[:use_cache]
        list, errors = if list.blank?
                         Rails.logger.info('mobile claims and appeals service fetch', user_uuid: @current_user.uuid)
                         service_list, service_errors = claims_proxy.get_claims_and_appeals
                         Mobile::V0::ClaimOverview.set_cached(@current_user, list)
                         [service_list, service_errors]
                       else
                         Rails.logger.info('mobile claims and appeals cache fetch', user_uuid: @current_user.uuid)
                         [list, []]
                       end

        status = get_response_status(errors)
        list = filter_by_date(params[:start_date], params[:end_date], list)
        list = filter_by_completed(list, show_completed) if show_completed.present?
        list, pagination_meta, links_meta = paginate(list, params, show_completed)
        options = { meta: { errors: errors, pagination: pagination_meta },
                    links: format_for_claims(links_meta, show_completed) }

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

      def paginate(list, params, _show_completed)
        total_entries = list.length
        page_size = params[:page_size]
        page_number = params[:page_number]
        total_pages = (total_entries / page_size.to_f).ceil
        [list.slice(((page_number - 1) * page_size), page_size),
         { currentPage: page_number, perPage: page_size, totalPages: total_pages, totalEntries: total_entries },
         Mobile::PaginationLinksHelper.links(total_pages,
                                             { page_size: page_size, page_number: page_number,
                                               start_date: params[:start_date], end_date: params[:end_date] },
                                             request)]
      end

      def fill_missing_params(params)
        [
          params[:startDate] || DateTime.new(1700).iso8601,
          params[:endDate] || (DateTime.now.utc.beginning_of_day + 1.year).iso8601,
          params[:page] || { number: 1, size: 10 },
          params[:useCache] || true
        ]
      end

      def get_response_status(errors)
        case errors.size
        when 1
          :multi_status
        when 2
          :bad_gateway
        else
          :ok
        end
      end

      def filter_by_date(start_date, end_date, list)
        list.filter do |entry|
          updated_at = entry[:updated_at]
          updated_at >= start_date && updated_at <= end_date
        end
      end

      def filter_by_completed(list, filter)
        list.filter do |entry|
          entry[:completed] == ActiveRecord::Type::Boolean.new.deserialize(filter)
        end
      end

      def format_for_claims(links, show_completed)
        if show_completed.present?
          {
            self: "#{links[:self]}&showCompleted=#{show_completed}",
            first: "#{links[:first]}&showCompleted=#{show_completed}",
            prev: links[:prev].present? ? "#{links[:prev]}&showCompleted=#{show_completed}" : links[:prev],
            next: links[:next].present? ? "#{links[:next]}&showCompleted=#{show_completed}" : links[:next],
            last: "#{links[:last]}&showCompleted=#{show_completed}"
          }
        end
      end
    end
  end
end
