# frozen_string_literal: true

require 'date'
require 'concurrent'
require 'chatbot/report_to_cxi'
require 'lighthouse/benefits_claims/service'

module V0
  module Chatbot
    class ClaimStatusController < SignIn::ServiceAccountApplicationController
      include IgnoreNotFound
      service_tag 'chatbot'
      rescue_from 'EVSS::ErrorMiddleware::EVSSError', with: :service_exception_handler

      def index
        render json: {
          data: poll_claims_from_lighthouse,
          meta: { sync_status: 'SUCCESS' }
        }
      end

      def show
        render json: {
          data: get_claim_from_lighthouse(params[:id]),
          meta: { sync_status: 'SUCCESS' }
        }
      end

      private

      def icn
        @icn ||= @service_account_access_token.user_attributes['icn']
      end

      def poll_claims_from_lighthouse
        cxi_reporting_service = ::Chatbot::ReportToCxi.new
        conversation_id = conversation_id_or_error
        claims = []

        begin
          raw_claim_list = lighthouse_service.get_claims['data']
          claims = order_claims_lighthouse(raw_claim_list)
        rescue Common::Exceptions::ResourceNotFound => e
          log_no_claims_found(e)
          claims = []
        rescue Faraday::ClientError => e
          service_exception_handler(e)
          raise BenefitsClaims::ServiceException.new(e.response), 'Could not retrieve claims'
        ensure
          report_or_error(cxi_reporting_service, conversation_id) if conversation_id.present?
        end

        claims
      end

      def conversation_id_or_error
        conversation_id = params[:conversation_id]
        return conversation_id if conversation_id.present?

        Rails.logger.error(conversation_id_missing_message)
        raise ActionController::ParameterMissing, 'conversation_id'
      end

      def get_claim_from_lighthouse(id)
        claim = lighthouse_service.get_claim(id)
        # Manual status override for certain tracked items
        # See https://github.com/department-of-veterans-affairs/va.gov-team/issues/101447
        # This should be removed when the items are re-categorized by BGS
        # We are not doing this in the Lighthouse service because we want web and mobile to have
        # separate rollouts and testing.
        claim = override_rv1(claim)
        # https://github.com/department-of-veterans-affairs/va.gov-team/issues/98364
        # This should be removed when the items are removed by BGS
        claim = suppress_evidence_requests(claim) if Flipper.enabled?(:cst_suppress_evidence_requests_website)
        claim
      end

      def override_rv1(claim)
        tracked_items = claim.dig('data', 'attributes', 'trackedItems')
        return claim unless tracked_items

        tracked_items.select { |i| i['displayName'] == 'RV1 - Reserve Records Request' }.each do |i|
          i['status'] = 'NEEDED_FROM_OTHERS'
        end
        claim
      end

      def suppress_evidence_requests(claim)
        tracked_items = claim.dig('data', 'attributes', 'trackedItems')
        return unless tracked_items

        tracked_items.reject! { |i| BenefitsClaims::Service::SUPPRESSED_EVIDENCE_REQUESTS.include?(i['displayName']) }
        claim
      end

      def lighthouse_service
        BenefitsClaims::Service.new(icn)
      end

      def report_or_error(cxi_reporting_service, conversation_id)
        cxi_reporting_service.report_to_cxi(icn, conversation_id)
      rescue => e
        report_exception_handler(e)
      end

      def order_claims_lighthouse(claims)
        Array(claims)
          .sort_by do |claim|
          Date.strptime(claim['attributes']['claimPhaseDates']['phaseChangeDate'],
                        '%Y-%m-%d').to_time.to_i
        end
          .reverse
      end

      def service_exception_handler(exception)
        context = 'An error occurred while attempting to retrieve the claim(s).'
        Rails.logger.error(formatted_exception_message(exception, context))
        render nothing: true, status: :service_unavailable
      end

      def report_exception_handler(exception)
        context = 'An error occurred while attempting to report the claim(s).'
        Rails.logger.error(formatted_exception_message(exception, context))
      end

      def formatted_exception_message(exception, context)
        return "#{context} #{exception.full_message(highlight: false)}" if exception.respond_to?(:full_message)

        backtrace = exception.backtrace ? "\n#{exception.backtrace.join("\n")}" : ''
        "#{context} #{exception.class}: #{exception.message}#{backtrace}"
      end

      def log_no_claims_found(exception)
        Rails.logger.info(
          'V0::Chatbot::ClaimStatusController#poll_claims_from_lighthouse ' \
          "no claims returned by Lighthouse: #{exception.message}"
        )
      end

      def conversation_id_missing_message
        'V0::Chatbot::ClaimStatusController#poll_claims_from_lighthouse ' \
          'conversation_id is missing in parameters'
      end

      class ServiceException < RuntimeError; end
    end
  end
end
