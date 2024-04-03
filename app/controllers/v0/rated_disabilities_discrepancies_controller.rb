# frozen_string_literal: true

require 'evss/disability_compensation_form/service'
require 'lighthouse/veteran_verification/service'

module V0
  class RatedDisabilitiesDiscrepanciesController < ApplicationController
    service_tag 'disability-rating'
    before_action { authorize :evss, :access? }
    before_action { authorize :lighthouse, :access? }

    DECISION_ALLOWLIST = ['1151 Denied', '1151 Granted', 'Not Service Connected', 'Service Connected'].freeze

    def show
      lh_response = get_lh_rated_disabilities
      evss_response = get_evss_rated_disabilities

      lh_ratings = lh_response.dig('data', 'attributes', 'individual_ratings')
      evss_ratings = evss_response.rated_disabilities
      if lh_ratings.length != evss_ratings.length
        log_length_discrepancy(evss_ratings, evss_ratings.length, lh_ratings,
                               lh_ratings.length)
      end

      # This doesn't need to return anything at the moment
      render json: nil
    end

    private

    def log_length_discrepancy(evss_ratings, evss_ratings_length, lh_ratings, lh_ratings_length)
      message = 'Discrepancy between Lighthouse and EVSS disability ratings'

      evss_ids = evss_ratings.pluck('rated_disability_id')
      lh_ids = lh_ratings.pluck('disability_rating_id')

      ::Rails.logger.info(message, {
                            message_type: 'lh.rated_disabilities.length_discrepancy',
                            evss_length: evss_ratings_length,
                            evss_rating_ids: evss_ids,
                            lighthouse_length: lh_ratings_length,
                            lighthouse_rating_ids: lh_ids,
                            revision: 5
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
      ratings.select! { |rating| DECISION_ALLOWLIST.include?(rating['decision']) }
    end

    def reject_inactive_ratings!(ratings)
      ratings.select! { |rating| active?(rating) }
    end

    def active?(rating)
      date = rating['rating_end_date']

      # In order for the rating to be considered active,
      # the date should be either nil or in the future
      date.nil? || Date.parse(date).future?
    end

    def service
      @service ||= VeteranVerification::Service.new
    end
  end
end
