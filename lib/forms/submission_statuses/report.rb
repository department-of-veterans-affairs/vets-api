# frozen_string_literal: true

require_relative 'benefits_intake_gateway'
require_relative 'formatters/benefits_intake_formatter'

module Forms
  module SubmissionStatuses
    class Report
      FORMATTERS = {
        'lighthouse_benefits_intake' => Formatters::BenefitsIntakeFormatter.new
      }.freeze

      def initialize(user_account:, allowed_forms:)
        @gateways = [
          { service: 'lighthouse_benefits_intake',
            gateway: BenefitsIntakeGateway.new(user_account:, allowed_forms:) }
        ]
      end

      def run
        data
        format_data
      rescue => e
        Rails.logger.error(
          'Report execution failed in Forms::SubmissionStatuses::Report',
          error: e.message,
          service: @current_service,
          error_source: @current_operation,
          backtrace: e.backtrace[0..5]
        )
        raise
      end

      def data
        @datasets = @gateways.map do |gateway_config|
          @current_service = gateway_config[:service]
          @current_operation = 'data_retrieval_from_gateway'

          response = gateway_config[:gateway].data

          if response.errors.present?
            Rails.logger.error(
              'Gateway errors encountered when retrieving data in Forms::SubmissionStatuses::Report',
              service: gateway_config[:service],
              errors: response.errors
            )
          end

          {
            service: gateway_config[:service],
            data: response
          }
        end
      end

      def format_data
        results = @datasets.flat_map do |dataset_config|
          service = dataset_config[:service]
          @current_service = service
          @current_operation = 'data_formatting'

          formatter = FORMATTERS[service]
          raise "Missing formatter for service: #{service}" unless formatter

          formatter.format_data(dataset_config[:data])
        end

        results = results.select do |result|
          submission_recent?(result)
        end

        OpenStruct.new(
          submission_statuses: results,
          errors: @datasets.flat_map do |dataset|
            dataset[:data].errors
          end.compact
        )
      end

      private

      def submission_recent?(submission)
        return submission.created_at >= 60.days.ago unless submission.updated_at

        submission.updated_at >= 60.days.ago
      end
    end
  end
end
