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

      def get_eligible_letter_types(icn)
        endpoint = 'eligible-letters'

        begin
          log = "Retrieving eligible letter types and destination from #{config.generator_url}/#{endpoint}"
          response = Lighthouse::LettersGenerator.measure_time(log) do
            config.connection.get(endpoint, { icn: })
          end
        rescue Faraday::ClientError, Faraday::ServerError => e
          Raven.tags_context(
            team: 'benefits-claim-appeal-status',
            feature: 'letters-generator'
          )
          raise Lighthouse::LettersGenerator::ServiceError.new(e.response[:body]), 'Lighthouse error'
        end

        {
          letters: response.body['letters'],
          letter_destination: response.body['letterDestination']
        }
      end

      # TODO: repeated code #get_eligible_letter_types
      def get_benefit_information(icn)
        endpoint = 'eligible-letters'

        begin
          log = "Retrieving benefit information from #{config.generator_url}/#{endpoint}"
          response = Lighthouse::LettersGenerator.measure_time(log) do
            config.connection.get(endpoint, { icn: })
          end
        rescue Faraday::ClientError, Faraday::ServerError => e
          Raven.tags_context(
            team: 'benefits-claim-appeal-status',
            feature: 'letters-generator'
          )
          raise Lighthouse::LettersGenerator::ServiceError.new(e.response[:body]), 'Lighthouse error'
        end

        { benefitInformation: response.body['benefitInformation'] }
      end

      def download_letter(icn, letter_type, options = {})
        unless LETTER_TYPES.include? letter_type.downcase
          error = Lighthouse::LettersGenerator::ServiceError.new
          error.title = 'Invalid letter type'
          error.message = "Letter type of #{letter_type.downcase} is not one of the expected options"
          error.status = 400

          raise error
        end

        endpoint = "letters/#{letter_type}/letter"
        letter_options = options.select { |_, v| v == true }

        begin
          log = "Retrieving benefit information from #{config.generator_url}/#{endpoint}"
          response = Lighthouse::LettersGenerator.measure_time(log) do
            config.connection.get(endpoint, { icn: }.merge(letter_options))
          end
        rescue Faraday::ClientError, Faraday::ServerError => e
          Raven.tags_context(team: 'benefits-claim-appeal-status', feature: 'letters-generator')
          raise Lighthouse::LettersGenerator::ServiceError.new(e.response[:body]), 'Lighthouse error'
        end

        response.body
      end
    end
  end
end
