# frozen_string_literal: true

require 'date'
require 'concurrent'
require 'lighthouse/benefits_claims/service'

module V0
  module VirtualAgent
    class VirtualAgentClaimController < ApplicationController
      include IgnoreNotFound
      rescue_from 'EVSS::ErrorMiddleware::EVSSError', with: :service_exception_handler
      unless Settings.vsp_environment == 'localhost' || Settings.vsp_environment == 'development'
        before_action { authorize :evss, :access? }
      end
      before_action { authorize :lighthouse, :access? }

      def index
        if Flipper.enabled?(:virtual_agent_lighthouse_claims, @current_user)
          poll_claims_from_lighthouse
        else
          poll_claims_from_evss
        end
      end

      def show
        unless Flipper.enabled?(:virtual_agent_lighthouse_claims, @current_user)
          claim = EVSSClaim.for_user(current_user).find_by(evss_id: params[:id])

          claim, synchronized = service.update_from_remote(claim)

          render json: {
            data: { va_representative: get_va_representative(claim) },
            meta: { sync_status: synchronized }
          }
        end
      end

      private

      def poll_claims_from_evss
        claims, synchronized = service.all
        cxdw_reporting_service = V0::VirtualAgent::ReportToCxdw.new
        conversation_id = params[:conversation_id]
        case synchronized
        when 'REQUESTED'
          render json: { data: nil, meta: { sync_status: synchronized } }
        when 'FAILED'
          error = EVSS::ErrorMiddleware::EVSSError.new('Could not retrieve claims')
          report_or_error(cxdw_reporting_service, conversation_id)
          service_exception_handler(error)
        else
          data_for_three_most_recent_open_comp_claims(claims)
          report_or_error(cxdw_reporting_service, conversation_id)
          render json: {
            data: data_for_three_most_recent_open_comp_claims(claims),
            meta: { sync_status: synchronized }
          }
        end
      end

      def poll_claims_from_lighthouse
        claims = lighthouse_service.get_claims
        cxdw_reporting_service = V0::VirtualAgent::ReportToCxdw.new
        conversation_id = params[:conversation_id]
        begin
          data_for_three_most_recent_open_comp_claims_lighthouse(claims)
          report_or_error(cxdw_reporting_service, conversation_id)
          render json: {
            data: data_for_three_most_recent_open_comp_claims_lighthouse(claims),
            meta: { sync_status: 'SUCCESS' }
          }
        rescue Faraday::ClientError => e
          report_or_error(cxdw_reporting_service, conversation_id)
          service_exception_handler(error)
          raise BenefitsClaims::ServiceException.new(e.response), 'Could not retrieve claims'
        end
      end

      def report_or_error(cxdw_reporting_service, conversation_id)
        cxdw_reporting_service.report_to_cxdw(current_user.icn, conversation_id)
      rescue => e
        report_exception_handler(e)
      end

      def data_for_three_most_recent_open_comp_claims(claims)
        comp_claims = three_most_recent_open_comp_claims claims

        return [] if comp_claims.nil?

        transform_claims_to_response(comp_claims)
      end

      def transform_claims_to_response(claims)
        claims.map { |claim| transform_single_claim_to_response(claim) }
      end

      def transform_single_claim_to_response(claim)
        status_type = claim.list_data['status_type']
        claim_status = claim.list_data['status']
        filing_date = claim.list_data['date']
        evss_id = claim.list_data['id']
        updated_date = get_updated_date(claim)

        { claim_status:,
          claim_type: status_type,
          filing_date:,
          evss_id:,
          updated_date: }
      end

      def three_most_recent_open_comp_claims(claims)
        claims
          .sort_by { |claim| parse_claim_date claim }
          .reverse
          .select { |claim| open_compensation? claim }
          .take(3)
      end

      def service
        EVSSClaimServiceAsync.new(current_user)
      end

      def parse_claim_date(claim)
        Date.strptime get_updated_date(claim), '%m/%d/%Y'
      end

      def get_updated_date(claim)
        claim.list_data['claim_phase_dates']['phase_change_date']
      end

      def data_for_three_most_recent_open_comp_claims_lighthouse(claims)
        comp_claims = three_most_recent_open_comp_claims_lighthouse claims

        return [] if comp_claims.nil?

        transform_claims_to_response_lighthouse(comp_claims)
      end

      def three_most_recent_open_comp_claims_lighthouse(claims)
        claims['data']
          .select { |claim| open_compensation_lighthouse? claim }
          .sort_by { |claim| transform_to_date(claim['attributes']['claimPhaseDates']['phaseChangeDate']) }
          .reverse
          .take(3)
      end

      def transform_to_date(field)
        spliced_date = field.split('-')
        rearranged_date = "#{spliced_date[1]}/#{spliced_date[2]}/#{spliced_date[0]}"
        Date.strptime(rearranged_date, '%m/%d/%Y')
      end

      def lighthouse_service
        BenefitsClaims::Service.new(current_user.icn)
      end

      def transform_claims_to_response_lighthouse(claims)
        claims.map { |claim| transform_single_claim_to_response_lighthouse(claim) }
      end

      def transform_single_claim_to_response_lighthouse(claim)
        status_type = claim['attributes']['claimType']
        claim_status = claim['attributes']['status']
        filing_date = transform_to_date(claim['attributes']['claimDate']).strftime('%m/%d/%Y')
        id = claim['id']
        updated_date = transform_to_date(claim['attributes']['claimPhaseDates']['phaseChangeDate']).strftime('%m/%d/%Y')

        { claim_status:,
          claim_type: status_type,
          filing_date:,
          id:,
          updated_date: }
      end

      def open_compensation_lighthouse?(claim)
        claim['attributes']['claimType'] == 'Compensation' and claim['attributes']['closeDate'].nil?
      end

      def open_compensation?(claim)
        claim.list_data['status_type'] == 'Compensation' and !claim.list_data.key?('close_date')
      end

      def get_va_representative(claim)
        va_rep = claim.data['poa']
        va_rep.gsub(/&[^ ;]+;/, '')
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
