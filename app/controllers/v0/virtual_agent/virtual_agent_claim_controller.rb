# frozen_string_literal: true

require 'date'
require 'concurrent'

module V0
  module VirtualAgent
    class VirtualAgentClaimController < ApplicationController
      include IgnoreNotFound

      rescue_from 'EVSS::ErrorMiddleware::EVSSError', with: :service_exception_handler

      before_action { authorize :evss, :access? }

      def index
        claims, synchronized = service.all

        case synchronized
        when 'REQUESTED'
          render json: {
            data: nil,
            meta: { sync_status: synchronized }
          }
        when 'FAILED'
          error = EVSS::ErrorMiddleware::EVSSError.new('Could not retrieve claims')
          service_exception_handler(error)
        else
          data_for_three_most_recent_open_comp_claims(claims)

          render json: {
            data: data_for_three_most_recent_open_comp_claims(claims),
            meta: { sync_status: synchronized }
          }
        end
      end

      def show
        claim = EVSSClaim.for_user(current_user).find_by(evss_id: params[:id])

        claim, synchronized = service.update_from_remote(claim)

        render json: {
          data: { va_representative: get_va_representative(claim) },
          meta: { sync_status: synchronized }
        }
      end

      private

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

        { claim_status: claim_status,
          claim_type: status_type,
          filing_date: filing_date,
          evss_id: evss_id,
          updated_date: updated_date }
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

      class ServiceException < RuntimeError; end
    end
  end
end
