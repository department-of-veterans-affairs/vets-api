# frozen_string_literal: true

# imports needed for evss
require 'common/exceptions/record_not_found'
require 'evss/letters/download_service'
require 'evss/letters/service'

# imports needed for lighthouse
require 'lighthouse/letters_generator/service'
require 'lighthouse/letters_generator/service_error'
require 'lighthouse/letters_generator/veteran_sponsor_resolver'

module V0
  class LettersDiscrepancyController < ApplicationController
    before_action { authorize :evss, :access_letters? }
    before_action { authorize :lighthouse, :access? }

    def index
      # Call evss endpoint
      evss_response = evss_service.get_letters
      # Call lighthouse endpoint
      lighthouse_response = lighthouse_service.get_eligible_letter_types(@current_user.icn)

      # Compare evss to lighthouse

      # evss_letters = (evss_response letter names put in an array)
      # lh_letters = (lighthouse_response letter names out in an array)
      # evss_letter_diff = (letter count difference for evss to lighthouse)
      # lh_letter_diff = (letter count difference for lighthouse to evss)

      # If statement that says:
          # return [] and no logs if (evss_letters.sort == lh_letters.sort)
          # then we know the arrays have the same count and the data is the same
          #
          # return [] and logs when
          # EXAMPLE: evss_letters = [1,2,3] and lh_letters = [1,5,6]
          # 
          # find the difference between evss_letters and lh_letters
          # evss_letters.difference(lh_letters) would return EVSSLetterDiff = [2,3] aka 2
          # find the difference between lh_letters and evss_letters
          # lh_letters.difference(evss_letters) would return LHLetterDiff = [5,6] aka 2
          # 
          # log the information
          # 
          # Log Example:
          # ::Rails.logger.info("EVSSLetterDiff: #{EVSSLetterDiff},
          # LHLetterDiff: #{LHLetterDiff}, 
          # EVSS Letters: #{evss_letters.join(', ')}, 
          # Lighthouse Letters: #{lh_letters.join(', ')}")
          # }

      # We are logging the magnitude of the difference between the list of
      # eligible letters returned by Lighthouse and EVSS to DataDog

      # The log includes the eligible letter type names returned by both services

      # A feature toggle has been created to allow us to turn this functionality on 
      # and off / control the number of users that are opted into this feature

      # There is a controller that calls both services to get the lists of eligible 
      # letters and logs to DataDog when there are discrepancies between the lists

      # When the controller sends a log to DataDog, there is a monitor in 
      # DataDog that will send an alert to our slack channel

    end

    private

    def evss_service
      EVSS::Letters::Service.new(@current_user)
    end

    def lighthouse_service
      @lighthouse_service ||= Lighthouse::LettersGenerator::Service.new
    end

  end
end