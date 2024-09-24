# frozen_string_literal: true

require 'lighthouse/benefits_intake/service'
require_relative 'dataset'
require_relative 'error_handler'

module Forms
  module SubmissionStatuses
    class Gateway
      attr_accessor :dataset

      def initialize(user_account:, allowed_forms:)
        @user_account = user_account
        @allowed_forms = allowed_forms
        @dataset = Forms::SubmissionStatuses::Dataset.new
        @error_handler = Forms::SubmissionStatuses::ErrorHandler.new
      end

      def data
        @dataset.submissions = submissions
        @dataset.intake_statuses, @dataset.errors = intake_statuses(@dataset.submissions) if @dataset.submissions?

        @dataset
      end

      def submissions
        query = FormSubmission.with_latest_benefits_intake_uuid(@user_account)
                              .with_form_types(@allowed_forms)
                              .order(:created_at)
        query.to_a
      end

      def intake_statuses(submissions)
        uuids = extract_uuids(submissions)
        response = fetch_bulk_status(uuids)
        process_response(response)
      rescue => e
        handle_intake_error(e)
      end

      private

      def extract_uuids(submissions)
        submissions.map(&:benefits_intake_uuid)
      end

      def fetch_bulk_status(uuids)
        intake_service.bulk_status(uuids:)
      end

      def process_response(response)
        [response.body['data'], nil]
      end

      def handle_intake_error(error)
        errors = @error_handler.handle_error(status: error.status, body: error.body)
        [nil, errors]
      end

      def intake_service
        @service ||= BenefitsIntake::Service.new
      end
    end
  end
end
