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
        json, status = fetch_all_cached_or_service(params)
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
        list, errors = if ActiveModel::Type::Boolean.new.cast(params[:useCache])
                         [Mobile::V0::ClaimOverview.get_cached(@current_user), []]
                       else
                         claims_proxy.get_claims_and_appeals
                       end

        options = {
          meta: {
            errors: errors
          }
        }

        status = case errors.size
                 when 1
                   :multi_status
                 when 2
                   :bad_gateway
                 else
                   :ok
                 end

        [Mobile::V0::ClaimOverviewSerializer.new(list, options), status]
      end

      def claims_proxy
        @claims_proxy ||= Mobile::V0::Claims::Proxy.new(@current_user)
      end
    end
  end
end
