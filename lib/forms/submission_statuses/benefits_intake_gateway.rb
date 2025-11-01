# frozen_string_literal: true

require 'lighthouse/benefits_intake/service'
require_relative 'dataset'
require_relative 'error_handler'

module Forms
  module SubmissionStatuses
    class BenefitsIntakeGateway
      attr_accessor :dataset

      # Define a proper struct for Lighthouse::Submissions
      SubmissionAdapter = Struct.new(:id, :form_id, :form_type, :created_at, :benefits_intake_uuid, :source)

      def initialize(user_account:, allowed_forms:)
        @user_account = user_account
        @allowed_forms = allowed_forms
        @dataset = Forms::SubmissionStatuses::Dataset.new
        @error_handler = Forms::SubmissionStatuses::ErrorHandler.new
      end

      def data
        @dataset.submissions = combined_submissions
        @dataset.intake_statuses, @dataset.errors = intake_statuses(@dataset.submissions) if @dataset.submissions?

        @dataset
      end

      def submissions
        query = FormSubmission.with_latest_benefits_intake_uuid(@user_account)
        query = query.with_form_types(@allowed_forms) if @allowed_forms.present?
        query.order(:created_at).to_a
      end

      def lighthouse_submissions
        query = Lighthouse::Submission.with_intake_uuid_for_user(@user_account)
        query = query.where(form_id: @allowed_forms) if @allowed_forms.present?
        query.order(:created_at).to_a
      end

      def combined_submissions
        form_submissions = submissions
        lighthouse_subs = lighthouse_submissions

        # Convert Lighthouse::Submissions to have benefits_intake_uuid for compatibility
        normalized_lighthouse = lighthouse_subs.map do |submission|
          SubmissionAdapter.new(
            submission.id,
            submission.form_id,
            submission.form_id, # For BenefitsIntakeFormatter
            submission.created_at,
            submission.latest_benefits_intake_uuid,
            'lighthouse_submission'
          )
        end

        # Combine and sort by creation time
        (form_submissions + normalized_lighthouse).sort_by(&:created_at)
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
        submissions.map(&:benefits_intake_uuid).compact
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
