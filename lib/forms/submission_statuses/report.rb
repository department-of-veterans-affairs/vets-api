# frozen_string_literal: true

require_relative 'gateway'
require_relative 'formatter'

module Forms
  module SubmissionStatuses
    class Report
      def initialize(user_account:, allowed_forms:)
        @gateway = Gateway.new(user_account:, allowed_forms:)
        @formatter = Formatter.new
      end

      def run
        data
        format_data
      end

      def data
        @dataset = @gateway.data
      end

      def format_data
        results = @formatter.format_data(@dataset)

        results = results.select do |result|
          submission_recent?(result)
        end

        OpenStruct.new(
          submission_statuses: results,
          errors: @dataset.errors
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
