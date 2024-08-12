# frozen_string_literal: true

require 'lighthouse/benefits_intake/service'
require_relative 'dataset'
require_relative 'error_handler'

module Forms
  module SubmissionStatuses
    class Gateway
      attr_accessor :dataset

      def initialize(user_account)
        @user_account = user_account
        @dataset = Forms::SubmissionStatuses::Dataset.new
        @error_handler = Forms::SubmissionStatuses::ErrorHandler.new
      end

      def data
        @dataset.submissions = submissions
        @dataset.intake_statuses, @dataset.errors = intake_statuses(@dataset.submissions) if @dataset.submissions?

        @dataset
      end

      def submissions
        FormSubmission.where(user_account: @user_account).to_a
      end

      def intake_statuses(submissions)
        uuids = submissions.map(&:benefits_intake_uuid)

        response = intake_service.bulk_status(uuids:)
        [response.body['data'], nil]
      rescue => e
        [nil, @error_handler.handle_error(e)]
      end

      private

      def intake_service
        @service ||= BenefitsIntake::Service.new
      end
    end
  end
end
