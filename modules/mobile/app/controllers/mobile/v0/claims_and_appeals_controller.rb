# frozen_string_literal: true

require_dependency 'mobile/application_controller'

module Mobile
  module V0
    class ClaimsAndAppealsController < ApplicationController
      include IgnoreNotFound

      before_action { authorize :evss, :access? }

      def index
        all_claims_lambda = -> { claims_service.all[0] }
        all_appeals_lambda = -> { appeals_service.get_appeals(@current_user).body['data'] }
        # results = Parallel.map([all_appeals_lambda, all_claims_lambda], in_threads: 8) do |current_lambda|
        #   current_lambda.call
        # end
        # binding.pry
        claims = all_claims_lambda.call
        appeals = all_appeals_lambda.call
        render json: Mobile::V0::ClaimsAndAppealsOverviewSerializer.new(@current_user.id, claims, appeals)
      end

      def claims_service
        @claims_service ||= EVSS::EVSSClaimService.new(@current_user)
      end

      def appeals_service
        @appeals_service ||= Caseflow::Service.new
      end
    end
  end
end
