# frozen_string_literal: true

# NOTE: extra imports shouldn't be needed in theory, but
# they sometimes cause the services to not load if they're not there

# imports needed for evss
require 'common/exceptions/record_not_found' # this shouldn't be needed
require 'evss/letters/download_service' # this shouldn't be needed
require 'evss/letters/service'

# imports needed for lighthouse
require 'lighthouse/letters_generator/service'
require 'lighthouse/letters_generator/service_error' # this shouldn't be needed

module V0
  class LettersDiscrepancyController < ApplicationController
    service_tag 'letters'
    before_action { authorize :evss, :access_letters? }
    before_action { authorize :lighthouse, :access? }

    def index
      # Call lighthouse endpoint
      lh_response = lh_service.get_eligible_letter_types(@current_user.icn)
      # Format response into lh_letters array
      lh_letters = lh_response[:letters].pluck(:letterType)

      # Call evss endpoint
      evss_response = evss_service.get_letters
      # Format response into evss_letters array
      evss_letters = evss_response.letters.map(&:letter_type)

      # Return if there are no differences
      unless lh_letters.sort == evss_letters.sort
        # Find difference between letters returned by each service
        lh_letter_diff = lh_letters.difference(evss_letters).count
        evss_letter_diff = evss_letters.difference(lh_letters).count
        # Log differences (will be monitored in DataDog)
        log_title = 'Letters Generator Discrepancies'
        ::Rails.logger.info(log_title,
                            { message_type: 'lh.letters_generator.letters_discrepancy',
                              lh_letter_diff:,
                              evss_letter_diff:,
                              lh_letters: lh_letters.sort.join(', '),
                              evss_letters: evss_letters.sort.join(', ') })
      end

      render json: []
    end

    private

    def evss_service
      EVSS::Letters::Service.new(@current_user)
    end

    # Lighthouse Service
    def lh_service
      @lh_service ||= Lighthouse::LettersGenerator::Service.new
    end
  end
end
