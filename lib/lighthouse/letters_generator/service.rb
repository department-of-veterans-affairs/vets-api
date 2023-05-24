# frozen_string_literal: true

require 'lighthouse/letters_generator/configuration'

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
      LETTER_TYPES = %w[
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
      ].to_set.freeze

      configuration Lighthouse::LettersGenerator::Configuration

      def transform_letters(letters)
        letters.map do |letter|
          {
            letterType: letter['letterType'].downcase,
            name: letter['letterName']
          }
        end
      end

      def transform_military_services(services_info)
        # transform
        services_info.map do |service|
          service[:enteredDate] = service.delete 'enteredDateTime'
          service[:releasedDate] = service.delete 'releasedDateTime'

          service.transform_keys(&:to_sym)
        end
      end

      def transform_benefit_information(info)
        transform_targets = {
          awardEffectiveDateTime: :awardEffectiveDate,
          chapter35Eligibility: :hasChapter35Eligibility,
          nonServiceConnectedPension: :hasNonServiceConnectedPension,
          serviceConnectedDisabilities: :hasServiceConnectedDisabilities,
          adaptedHousing: :hasAdaptedHousing,
          individualUnemployabilityGranted: :hasIndividualUnemployabilityGranted,
          specialMonthlyCompensation: :hasSpecialMonthlyCompensation
        }

        symbolized_info = info.deep_transform_keys(&:to_sym)

        transformed_info = symbolized_info.reduce({}) do |acc, (k, v)|
          if transform_targets.key? k
            acc.merge({ transform_targets[k] => v })
          else
            acc.merge({ k => v })
          end
        end

        # Don't return chapter35EligibilityDateTime
        # It's not used on the frontend, and in fact causes problems
        transformed_info.merge(
          { monthlyAwardAmount: symbolized_info[:monthlyAwardAmount][:value] }
        ).except(:chapter35EligibilityDateTime)
      end

      def get_eligible_letter_types(icn)
        endpoint = 'eligible-letters'

        begin
          log = "Retrieving eligible letter types and destination from #{config.generator_url}/#{endpoint}"
          response = Lighthouse::LettersGenerator.measure_time(log) do
            config.connection.get(endpoint, { icn: }, { Authorization: "Bearer #{config.get_access_token}" })
          end
        rescue Faraday::ClientError, Faraday::ServerError => e
          Raven.tags_context(
            team: 'benefits-claim-appeal-status',
            feature: 'letters-generator'
          )
          raise Lighthouse::LettersGenerator::ServiceError.new(e.response[:body]), 'Lighthouse error'
        end

        {
          letters: transform_letters(response.body['letters']),
          letter_destination: response.body['letterDestination']
        }
      end

      # TODO: repeated code #get_eligible_letter_types
      def get_benefit_information(icn)
        endpoint = 'eligible-letters'

        begin
          log = "Retrieving benefit information from #{config.generator_url}/#{endpoint}"
          response = Lighthouse::LettersGenerator.measure_time(log) do
            config.connection.get(endpoint, { icn: }, { Authorization: "Bearer #{config.get_access_token}" })
          end
        rescue Faraday::ClientError, Faraday::ServerError => e
          Raven.tags_context(
            team: 'benefits-claim-appeal-status',
            feature: 'letters-generator'
          )
          raise Lighthouse::LettersGenerator::ServiceError.new(e.response[:body]), 'Lighthouse error'
        end

        {
          benefitInformation: transform_benefit_information(response.body['benefitInformation']),
          militaryService: transform_military_services(response.body['militaryServices'])
        }
      end

      def download_letter(icn, letter_type, options = {})
        unless LETTER_TYPES.include? letter_type.downcase
          error = create_invalid_type_error(letter_type.downcase)
          raise error
        end

        endpoint = "letters/#{letter_type}/letter"
        letter_options = options.select { |_, v| v == true }

        begin
          log = "Retrieving benefit information from #{config.generator_url}/#{endpoint}"
          response = Lighthouse::LettersGenerator.measure_time(log) do
            config.connection.get(
              endpoint,
              { icn: }.merge(letter_options),
              { Authorization: "Bearer #{config.get_access_token}" }
            )
          end
        rescue Faraday::ClientError, Faraday::ServerError => e
          Raven.tags_context(team: 'benefits-claim-appeal-status', feature: 'letters-generator')
          raise Lighthouse::LettersGenerator::ServiceError.new(e.response[:body]), 'Lighthouse error'
        end

        response.body
      end

      def create_invalid_type_error(letter_type)
        error = Lighthouse::LettersGenerator::ServiceError.new
        error.title = 'Invalid letter type'
        error.message = "Letter type of #{letter_type.downcase} is not one of the expected options"
        error.status = 400

        error
      end
    end
  end
end
