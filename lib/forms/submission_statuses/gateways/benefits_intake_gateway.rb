# frozen_string_literal: true

require 'lighthouse/benefits_intake/service'
require_relative '../dataset'
require_relative '../error_handler'
require_relative 'base_gateway'

module Forms
  module SubmissionStatuses
    module Gateways
      class BenefitsIntakeGateway < BaseGateway
        def submissions
          query = FormSubmission.with_latest_benefits_intake_uuid(user_account)
          query = query.with_form_types(allowed_forms) if allowed_forms.present?
          query.order(:created_at).to_a
        end

        def api_statuses(submissions)
          intake_statuses(submissions)
        end

        private

        def intake_statuses(submissions)
          uuids = extract_uuids(submissions)
          response = fetch_bulk_status(uuids)
          process_response(response)
        rescue => e
          handle_intake_error(e)
        end

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
          errors = if error.is_a?(Common::Exceptions::BackendServiceException)
                     # BackendServiceException uses original_status/original_body
                     error_handler.handle_error(status: error.original_status, body: error.original_body)
                   else
                     # For other errors, create a generic error message
                     ["Service error: #{error.message}"]
                   end
          [nil, errors]
        end

        def intake_service
          @service ||= BenefitsIntake::Service.new
        end
      end
    end
  end
end
