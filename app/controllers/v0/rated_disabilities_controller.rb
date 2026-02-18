# frozen_string_literal: true

require 'lighthouse/veteran_verification/service'

module V0
  # Controller for fetching rated disabilities from Lighthouse Veteran Verification API.
  # Retrieves disability ratings for authenticated veterans and filters to active ratings only.
  class RatedDisabilitiesController < ApplicationController
    service_tag 'disability-rating'
    before_action { authorize :lighthouse, :access? }

    # Fetches rated disabilities for the current user from Lighthouse.
    # Returns only active ratings (those without an end date or with a future end date).
    # Scrubs the veteran's ICN from the response before returning to the frontend.
    #
    # @return [JSON] Response body containing rated disabilities data
    def show
      response = service.get_rated_disabilities(@current_user.icn)

      # We only want active ratings
      if response.dig('data', 'attributes', 'individual_ratings')
        remove_inactive_ratings!(response['data']['attributes']['individual_ratings'])
      end

      # LH returns the ICN of the Veteran in the data.id field
      # We want to scrub it out before sending to the FE
      response['data']['id'] = ''

      render json: response
    rescue => e
      log_error(e)
      raise
    end

    private

    # Determines if a disability rating is currently active.
    # A rating is active if it has no end date or the end date is in the future.
    #
    # @param rating [Hash] Individual rating object from Lighthouse response
    # @return [Boolean] True if the rating is active, false otherwise
    def active?(rating)
      end_date = rating['rating_end_date']

      end_date.nil? || Date.parse(end_date).future?
    end

    # Filters an array of ratings to keep only active ratings.
    # Modifies the array in place.
    #
    # @param ratings [Array<Hash>] Array of individual rating objects
    # @return [Array<Hash>] Array with only active ratings (mutated in place)
    def remove_inactive_ratings!(ratings)
      ratings.select! { |rating| active?(rating) }
    end

    # Returns the Lighthouse Veteran Verification service instance.
    #
    # @return [VeteranVerification::Service] Memoized service instance
    def service
      @service ||= VeteranVerification::Service.new
    end

    # Logs detailed error information for troubleshooting.
    # Includes error class, message, user context
    #
    # @param exception [Exception] The exception to log
    # @return [void]
    def log_error(exception)
      Rails.logger.error(
        'RatedDisabilitiesController error',
        {
          error_class: exception.class.name,
          error_message: exception.message,
          user_uuid: @current_user&.uuid
        }
      )
    end
  end
end
