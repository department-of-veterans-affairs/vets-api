# frozen_string_literal: true

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
      before_action(only: :index) do
        if Flipper.enabled?(:mobile_lighthouse_claims, @current_user)
          authorize :lighthouse, :access?
        else
          authorize :evss, :access?
        end
      end

      before_action(except: :index) do
        authorize :evss, :access?
      end

      after_action only: :upload_multi_image_document do
        evss_claims_proxy.cleanup_after_upload
      end

      def index
        validated_params = validate_params

        json, status = fetch_all_cached_or_service(validated_params, params[:showCompleted])
        render json:, status:
      end

      def get_claim
        claim_detail = evss_claims_proxy.get_claim(params[:id])
        render json: Mobile::V0::ClaimSerializer.new(claim_detail)
      end

      def get_appeal
        appeal = evss_claims_proxy.get_appeal(params[:id])
        render json: Mobile::V0::AppealSerializer.new(appeal)
      end

      def request_decision
        jid = evss_claims_proxy.request_decision(params[:id])
        render json: { data: { job_id: jid } }, status: :accepted
      end

      def upload_document
        jid = evss_claims_proxy.upload_document(params)
        render json: { data: { job_id: jid } }, status: :accepted
      end

      def upload_multi_image_document
        jid = evss_claims_proxy.upload_multi_image(params)
        render json: { data: { job_id: jid } }, status: :accepted
      end

      private

      def fetch_all_cached_or_service(validated_params, show_completed)
        list = nil
        list = Mobile::V0::ClaimOverview.get_cached(@current_user) if validated_params[:use_cache]
        list, errors = if list.nil?
                         if Flipper.enabled?(:mobile_lighthouse_claims, @current_user)
                           service_list, service_errors = lighthouse_claims_proxy.get_claims_and_appeals
                         else
                           service_list, service_errors = evss_claims_proxy.get_claims_and_appeals
                         end
                         Mobile::V0::ClaimOverview.set_cached(@current_user, list)
                         [service_list, service_errors]
                       else
                         [list, []]
                       end

        status = get_response_status(errors)
        list = filter_by_date(validated_params[:start_date], validated_params[:end_date], list)
        list = filter_by_completed(list, show_completed) if show_completed.present?
        list, meta = paginate(list, validated_params)

        options = { meta: { errors:, pagination: meta.dig(:meta, :pagination) },
                    links: meta[:links] }

        [Mobile::V0::ClaimOverviewSerializer.new(list, options), status]
      end

      def lighthouse_claims_proxy
        @claims_proxy ||= Mobile::V0::LighthouseClaims::Proxy.new(@current_user)
      end

      def evss_claims_proxy
        @claims_proxy ||= Mobile::V0::Claims::Proxy.new(@current_user)
      end

      def validate_params
        Mobile::V0::Contracts::ClaimsAndAppeals.new.call(pagination_params)
      end

      def paginate(list, validated_params)
        Mobile::PaginationHelper.paginate(list:, validated_params:)
      end

      def pagination_params
        pagination_params = {
          start_date: params[:startDate] || DateTime.new(1700).iso8601,
          end_date: params[:endDate] || (DateTime.now.utc.beginning_of_day + 1.year).iso8601,
          page_number: params.dig(:page, :number),
          page_size: params.dig(:page, :size),
          use_cache: params[:useCache] || true
        }
        pagination_params[:show_completed] = params[:showCompleted] if params[:showCompleted].present?
        pagination_params
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
    end
  end
end
