# frozen_string_literal: true

require 'date'
require 'concurrent'
require 'lighthouse/benefits_claims/service'

module V0
  module VirtualAgent
    class VirtualAgentClaimStatusController < ApplicationController
      include IgnoreNotFound
      service_tag 'virtual-agent'
      rescue_from 'EVSS::ErrorMiddleware::EVSSError', with: :service_exception_handler
      unless %w[localhost development].include?(Settings.vsp_environment.downcase)
        before_action { authorize :lighthouse, :access? }
      end

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

      def poll_claims_from_lighthouse
        raw_claim_list = lighthouse_service.get_claims['data']
        cxdw_reporting_service = V0::VirtualAgent::ReportToCxdw.new
        conversation_id = params[:conversation_id]
        if conversation_id.blank?
          Rails.logger.error(
            'V0::VirtualAgent::VirtualAgentClaimStatusController#poll_claims_from_lighthouse ' \
            'conversation_id is missing in parameters'
          )
          raise ActionController::ParameterMissing, 'conversation_id'
        end

        begin
          claims = order_claims_lighthouse(raw_claim_list)
          report_or_error(cxdw_reporting_service, conversation_id)
          claims
        rescue Faraday::ClientError => e
          report_or_error(cxdw_reporting_service, conversation_id)
          service_exception_handler(error)
          raise BenefitsClaims::ServiceException.new(e.response), 'Could not retrieve claims'
        end
      end

      def get_claim_from_lighthouse(id)
        claim = lighthouse_service.get_claim(id)
        # Manual status override for certain tracked items
        # See https://github.com/department-of-veterans-affairs/va.gov-team/issues/101447
        # This should be removed when the items are re-categorized by BGS
        # We are not doing this in the Lighthouse service because we want web and mobile to have
        # separate rollouts and testing.
        claim = override_rv1(claim) if Flipper.enabled?(:cst_override_reserve_records_website)
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
        BenefitsClaims::Service.new(current_user.icn)
      end

      def report_or_error(cxdw_reporting_service, conversation_id)
        cxdw_reporting_service.report_to_cxdw(current_user.icn, conversation_id)
      rescue => e
        report_exception_handler(e)
      end

      def order_claims_lighthouse(claims)
        claims
          .sort_by do |claim|
          Date.strptime(claim['attributes']['claimPhaseDates']['phaseChangeDate'],
                        '%Y-%m-%d').to_time.to_i
        end
          .reverse
      end

      def service_exception_handler(exception)
        context = 'An error occurred while attempting to retrieve the claim(s).'
        log_exception_to_sentry(exception, 'context' => context)
        render nothing: true, status: :service_unavailable
      end

      def report_exception_handler(exception)
        context = 'An error occurred while attempting to report the claim(s).'
        log_exception_to_sentry(exception, 'context' => context)
      end

      class ServiceException < RuntimeError; end
    end
  end
end
