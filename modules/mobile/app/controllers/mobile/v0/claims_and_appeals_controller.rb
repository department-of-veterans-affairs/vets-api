# frozen_string_literal: true

require_dependency 'mobile/application_controller'
require_relative '../../../models/mobile/v0/adapters/claims_overview'
require_relative '../../../models/mobile/v0/adapters/claims_overview_errors'
require_relative '../../../models/mobile/v0/claim_overview'

module Mobile
  module V0
    class ClaimsAndAppealsController < ApplicationController
      include IgnoreNotFound
      before_action { authorize :evss, :access? }

      def index
        get_all_claims = lambda {
          begin
            claims_list = claims_service.all_claims
            [claims_list.body['open_claims'].push(*claims_list.body['historical_claims']).flatten, true]
          rescue => e
            [Mobile::V0::Adapters::ClaimsOverviewErrors.new.parse(e, 'claims'), false]
          end
        }

        get_all_appeals = lambda {
          begin
            [appeals_service.get_appeals(@current_user).body['data'], true]
          rescue => e
            [Mobile::V0::Adapters::ClaimsOverviewErrors.new.parse(e, 'appeals'), false]
          end
        }
        results = Parallel.map([get_all_claims, get_all_appeals], in_threads: 2, &:call)
        status_code = parse_claims(results[0], full_list = [], error_list = [])
        status_code = parse_appeals(results[1], full_list, error_list, status_code)
        adapted_full_list = serialize_list(full_list.flatten)
        render json: { data: adapted_full_list, meta: { errors: error_list } }, status: status_code
      end

      private

      def parse_claims(claims, full_list, error_list)
        if claims[1]
          # claims success
          full_list.push(claims[0].map { |claim| create_or_update_claim(claim) })
          :ok
        else
          # claims error
          error_list.push(claims[0])
          :multi_status
        end
      end

      def parse_appeals(appeals, full_list, error_list, status_code)
        if appeals[1]
          # appeals success
          full_list.push(appeals[0])
          status_code
        else
          # appeals error
          error_list.push(appeals[0])
          status_code == :multi_status ? :bad_gateway : :multi_status
        end
      end

      def serialize_list(full_list)
        adapted_full_list = full_list.map { |entry| Mobile::V0::Adapters::ClaimsOverview.new.parse(entry) }
        adapted_full_list = adapted_full_list.sort_by { |entry| entry[:date_filed] }.reverse!
        adapted_full_list = adapted_full_list.map { |entry| Mobile::V0::ClaimOverview.new(entry) }
        adapted_full_list.map do |entry|
          JSON.parse(Mobile::V0::ClaimOverviewSerializer.new(entry).serialized_json)['data']
        end
      end

      def claims_service
        @claims_service ||= EVSS::ClaimsService.new(auth_headers)
      end

      def auth_headers
        @auth_headers ||= EVSS::AuthHeaders.new(@current_user).to_h
      end

      def appeals_service
        @appeals_service ||= Caseflow::Service.new
      end

      def claims_scope
        EVSSClaim.for_user(@current_user)
      end

      def create_or_update_claim(raw_claim)
        claim = claims_scope.where(evss_id: raw_claim['id']).first_or_initialize(data: {})
        claim.update(list_data: raw_claim)
        claim
      end
    end
  end
end
