# frozen_string_literal: true

require 'lighthouse/benefits_intake/service'
require_relative '../dataset'
require_relative '../error_handler'
require_relative 'base_gateway'

module Forms
  module SubmissionStatuses
    module Gateways
      class BenefitsIntakeGateway < BaseGateway
        # Define a proper struct for Lighthouse::Submissions
        SubmissionAdapter = Struct.new(:id, :form_id, :form_type, :created_at, :benefits_intake_uuid, :source)

        def submissions
          combined_submissions
        end

        def form_submissions
          query = FormSubmission.with_latest_benefits_intake_uuid(user_account)
          query = query.with_form_types(allowed_forms) if allowed_forms.present?
          query.order(:created_at).to_a
        end

        def lighthouse_submissions
          query = Lighthouse::Submission.with_intake_uuid_for_user(user_account)
          query = query.where(form_id: allowed_forms) if allowed_forms.present?
          query.order(:created_at).to_a
        end

        def combined_submissions
          form_subs = form_submissions
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
          (form_subs + normalized_lighthouse).sort_by(&:created_at)
        end

        def api_statuses(submissions)
          intake_statuses(submissions)
        end

        private

        def intake_statuses(submissions)
          uuids = extract_uuids(submissions)
          response = fetch_bulk_status(uuids)
          process_response(response)
        rescue => e # Catches BackendServiceException and Faraday errors
          handle_intake_error(e)
        end

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
          errors = if error.is_a?(Common::Exceptions::BackendServiceException)
                     # BackendServiceException uses original_status/original_body
                     error_handler.handle_error(status: error.original_status, body: error.original_body)
                   else
                     # For other errors, extract the status if possible and use error_handler
                     status = extract_status_from_error(error)
                     body = { message: error.message || error.to_s }
                     error_handler.handle_error(status:, body:)
                   end
          [nil, errors]
        end

        def extract_status_from_error(error)
          # Check if error has a status method (like Faraday errors)
          return error.status if error.respond_to?(:status)

          # Try to extract status from error message
          # e.g., "the server responded with status 401"
          if error.message =~ /status (\d{3})/
            ::Regexp.last_match(1).to_i
          else
            500 # Default to 500 if we can't determine the status
          end
        end

        def intake_service
          @service ||= BenefitsIntake::Service.new
        end
      end
    end
  end
end
