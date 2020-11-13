# frozen_string_literal: true

require_dependency 'mobile/application_controller'

module Mobile
  module V0
    class ClaimsAndAppealsController < ApplicationController
      include IgnoreNotFound

      before_action { authorize :evss, :access? }

      def index
        all_claims_lambda = -> {
          begin
            claims_list = claims_service.all_claims
            [].push(claims_list.body['open_claims']).push(claims_list.body['historical_claims']).flatten
          rescue Exception => ex
            ex
          end
        }
        all_appeals_lambda = -> {
          begin
            appeals_service.get_appeals(@current_user).body['data']
          rescue Exception => ex
            ex
          end
        }
        results = Parallel.map([all_claims_lambda, all_appeals_lambda], in_threads: 8) do |current_lambda|
          current_lambda.call
        end
        # catch and react to errors some where
        render json: Mobile::V0::ClaimsAndAppealsOverviewSerializer.new(@current_user.id, results[0], results[1])
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
    end
  end
end
