# frozen_string_literal: true

require 'date'

module V0
  module VirtualAgent
    class VirtualAgentClaimController < ApplicationController
      include IgnoreNotFound

      before_action { authorize :evss, :access? }

      def index
        claims, synchronized = service.all

        data = synchronized == 'REQUESTED' ? nil : data_for_first_comp_claim(claims)

        render json: {
          data: data,
          meta: { sync_status: synchronized }
        }
      end

      private

      def data_for_first_comp_claim(claims)
        comp_claim = first_open_comp_claim claims

        return [] if comp_claim.nil?

        [transform_claim_to_response(comp_claim)]
      end

      def transform_claim_to_response(claim)
        status_type = claim.list_data['status_type']
        claim_status = claim.list_data['status']
        filing_date = claim.list_data['date']
        evss_id = claim.list_data['id']

        { claim_status: claim_status,
          claim_type: status_type,
          filing_date: filing_date,
          evss_id: evss_id }
      end

      def first_open_comp_claim(claims)
        claims
          .sort_by { |claim| parse_claim_date claim }
          .reverse
          .find { |claim| open_compensation? claim }
      end

      def service
        EVSSClaimServiceAsync.new(current_user)
      end

      def parse_claim_date(claim)
        Date.strptime claim.list_data['date'], '%m/%d/%Y'
      end

      def open_compensation?(claim)
        claim.list_data['status_type'] == 'Compensation' and !claim.list_data.key?('close_date')
      end
    end
  end
end
