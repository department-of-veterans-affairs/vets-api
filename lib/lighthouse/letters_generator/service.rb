# frozen_string_literal: true

require 'lighthouse/letters_generator/configuration'
require 'lighthouse/letters_generator/service_error'
require 'lighthouse/service_exception'
require 'common/exceptions/bad_request'

module Lighthouse
  module LettersGenerator
    def self.measure_time(msg)
      start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)

      response = yield

      end_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      elapsed = end_time - start_time

      Rails.logger.info "#{msg}: #{elapsed} seconds"
      response
    end

    class Service < Common::Client::Base
      BENEFICIARY_KEY_TRANFORMS = {
        awardEffectiveDateTime: :awardEffectiveDate,
        chapter35Eligibility: :hasChapter35Eligibility,
        nonServiceConnectedPension: :hasNonServiceConnectedPension,
        serviceConnectedDisabilities: :hasServiceConnectedDisabilities,
        adaptedHousing: :hasAdaptedHousing,
        individualUnemployabilityGranted: :hasIndividualUnemployabilityGranted,
        specialMonthlyCompensation: :hasSpecialMonthlyCompensation
      }.freeze

      configuration Lighthouse::LettersGenerator::Configuration

      def get_letter(icn, letter_type, options = {})
        endpoint = "letter-contents/#{letter_type}"
        log = "Retrieving letter from #{config.generator_url}/#{endpoint}"
        params = { icn: }.merge(options)

        response = get_from_lighthouse(endpoint, params, log)
        response.body
      end

      def get_eligible_letter_types(icn)
        endpoint = 'eligible-letters'
        log = "Retrieving eligible letter types and destination from #{config.generator_url}/#{endpoint}"
        params = { icn: }

        response = get_from_lighthouse(endpoint, params, log)
        {
          letters: transform_letters(response.body['letters']),
          letter_destination: response.body['letterDestination']
        }
      end

      def get_benefit_information(icn)
        endpoint = 'eligible-letters'
        log = "Retrieving benefit information from #{config.generator_url}/#{endpoint}"
        params = { icn: }

        response = get_from_lighthouse(endpoint, params, log)
        {
          benefitInformation: transform_benefit_information(response.body['benefitInformation']),
          militaryService: transform_military_services(response.body['militaryServices'])
        }
      end

      def download_letter(icns, letter_type, options = {})
        endpoint = "letters/#{letter_type}/letter"
        log = "Downloading letter from #{config.generator_url}/#{endpoint}"
        params = icns.merge(options)

        response = get_from_lighthouse(endpoint, params, log)
        response.body
      end

      def valid_type?(letter_type)
        letter_types.include? letter_type.downcase
      end

      private

      def letter_types
        list = %w[
          benefit_summary
          benefit_summary_dependent
          benefit_verification
          certificate_of_eligibility
          civil_service
          commissary
          medicare_partd
          minimum_essential_coverage
          proof_of_service
          service_verification
        ]
        list = list.excluding('service_verification') if Flipper.enabled?(:letters_hide_service_verification_letter)
        list << 'foreign_medical_program' if Flipper.enabled?(:fmp_benefits_authorization_letter)
        list.to_set.freeze
      end

      def get_from_lighthouse(endpoint, params, log)
        Lighthouse::LettersGenerator.measure_time(log) do
          config.connection.get(
            endpoint,
            params,
            { Authorization: "Bearer #{config.get_access_token}" }
          )
        end
      rescue Faraday::ClientError, Faraday::ServerError => e
        Sentry.set_tags(
          team: 'benefits-claim-appeal-status',
          feature: 'letters-generator'
        )

        handle_error(e, config.service_name, endpoint)
      end

      def handle_error(error, lighthouse_client_id, endpoint)
        Lighthouse::ServiceException.send_error(
          error,
          self.class.to_s.underscore,
          lighthouse_client_id,
          "#{config.generator_url}/#{endpoint}"
        )
      end

      def transform_letters(letters)
        letters.select! { |l| valid_type?(l['letterType']) }
        letters.map do |letter|
          {
            letterType: letter['letterType'].downcase,
            name: letter['letterName']
          }
        end
      end

      def transform_military_services(services_info)
        services_info.map do |service|
          service[:enteredDate] = service.delete 'enteredDateTime'
          service[:releasedDate] = service.delete 'releasedDateTime'

          service.transform_keys(&:to_sym)
        end
      end

      def transform_benefit_information(info)
        symbolized_info = info.deep_transform_keys(&:to_sym)

        transformed_info = symbolized_info.reduce({}) do |acc, (k, v)|
          if BENEFICIARY_KEY_TRANFORMS.key? k
            acc.merge({ BENEFICIARY_KEY_TRANFORMS[k] => v })
          else
            acc.merge({ k => v })
          end
        end

        monthly_award_amount = symbolized_info[:monthlyAwardAmount] ? symbolized_info[:monthlyAwardAmount][:value] : 0

        # Don't return chapter35EligibilityDateTime
        # It's not currently (June 2023) used on the frontend, and in fact causes problems
        transformed_info
          .merge({ monthlyAwardAmount: monthly_award_amount })
          .except(:chapter35EligibilityDateTime)
      end

      def create_invalid_type_error(letter_type)
        error = {}
        error['title'] = 'Invalid letter type'
        error['message'] = "Letter type of #{letter_type.downcase} is not one of the expected options"
        error['status'] = 400

        error
      end
    end
  end
end
