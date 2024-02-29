# frozen_string_literal: true

require 'lighthouse/veteran_verification/service'
require 'lighthouse/veteran_verification/rated_disabilities/response'
require 'lighthouse/veteran_verification/rated_disabilities/serializer'

module V0
  class RatedDisabilitiesController < ApplicationController
    service_tag 'disability-rating'
    before_action { authorize :lighthouse, :access? }

    DECISION_ALLOWLIST = ['1151 Denied', '1151 Granted', 'Not Service Connected', 'Service Connected'].freeze

    def show
      raw_response = service.get_rated_disabilities('1012830774V793840')

      attributes = raw_response.dig('data', 'attributes')

      response = VeteranVerification::RatedDisabilitiesResponse.new(attributes)
      response.filter_by_decision!(DECISION_ALLOWLIST)
      response.filter_by_inactivity!

      render json: response, serializer: VeteranVerification::RatedDisabilitiesSerializer
    end

    private

    def service
      @service ||= VeteranVerification::Service.new
    end
  end
end
