# frozen_string_literal: true

require 'evss/disability_compensation_form/service'
require 'lighthouse/veteran_verification/service'

module V0
  class RatedDisabilitiesDiscrepanciesController < ApplicationController
    service_tag 'disability-rating'
    before_action { authorize :evss, :access? }
    before_action { authorize :lighthouse, :access? }

    DECISION_ALLOWLIST = ['1151 Granted', 'Not Service Connected', 'Service Connected'].freeze

    def show
      lh_response = get_lh_rated_disabilities
      evss_response = get_evss_rated_disabilities

      lh_response_length = lh_response.dig('data', 'attributes', 'individual_ratings').length
      evss_response_length = evss_response.rated_disabilities.length

      if lh_response_length != evss_response_length
        log_length_discrepancy((lh_response_length - evss_response_length).abs)
      end

      # This doesn't need to return anything at the moment
      render json: nil
    end

    private

    def log_length_discrepancy(difference)
      message = "Discrepancy of #{difference} disability ratings"

      ::Rails.logger.info(message, {
                            message_type: 'lh.rated_disabilities.length_discrepancy',
                            revision: 3
                          })
    end

    # EVSS
    def evss_service
      auth_headers = get_auth_headers
      @evss_service ||= EVSS::DisabilityCompensationForm::Service.new(auth_headers)
    end

    def get_auth_headers
      EVSS::AuthHeaders.new(@current_user).to_h
    end

    def get_evss_rated_disabilities
      evss_service.get_rated_disabilities
    end

    # Lighthouse
    def get_lh_rated_disabilities
      response = service.get_rated_disabilities(@current_user.icn)

      # We only want active ratings
      if response.dig('data', 'attributes', 'individual_ratings')
        filter_ratings_by_decision!(response['data']['attributes']['individual_ratings'])
        reject_inactive_ratings!(response['data']['attributes']['individual_ratings'])
      end

      response
    end

    def filter_ratings_by_decision!(ratings)
      ratings.select! { |rating| DECISION_ALLOWLIST.include?(rating[:decision]) }
    end

    def reject_inactive_ratings!(ratings)
      ratings.select! { |rating| active?(rating) }
    end

    def active?(rating)
      rating['rating_end_date'].nil?
    end

    def deferred?(rating)
      rating['decision'] == 'Deferred'
    end

    def service
      @service ||= VeteranVerification::Service.new
    end
  end
end
