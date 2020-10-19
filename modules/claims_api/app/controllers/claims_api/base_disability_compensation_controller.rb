# frozen_string_literal: true

require 'evss/disability_compensation_form/service'
require 'evss/disability_compensation_form/service_exception'
require 'evss/error_middleware'
require 'common/exceptions'

module ClaimsApi
  class BaseDisabilityCompensationController < ClaimsApi::BaseFormController
    STATSD_VALIDATION_FAIL_KEY = 'api.claims_api.526.validation_fail'
    STATSD_VALIDATION_FAIL_TYPE_KEY = 'api.claims_api.526.validation_fail_type'

    # TODO: Fix methods in document_validations to work correctly before uncommenting, add broader range of tests
    # before_action :validate_documents_content_type, only: %i[upload_form_526]
    # before_action :validate_documents_page_size, only: %i[upload_form_526]

    def upload_form_526
      pending_claim = ClaimsApi::AutoEstablishedClaim.pending?(params[:id])
      pending_claim.set_file_data!(documents.first, params[:doc_type])
      pending_claim.save!

      ClaimsApi::ClaimUploader.perform_async(pending_claim.id)

      render json: pending_claim, serializer: ClaimsApi::AutoEstablishedClaimSerializer
    rescue => e
      render json: unprocessable_response(e), status: :unprocessable_entity
    end

    # rubocop:disable Metrics/MethodLength
    def validate_form_526
      service = EVSS::DisabilityCompensationForm::Service.new(auth_headers)
      auto_claim = ClaimsApi::AutoEstablishedClaim.new(
        status: ClaimsApi::AutoEstablishedClaim::PENDING,
        auth_headers: auth_headers,
        form_data: form_attributes
      )
      service.validate_form526(auto_claim.to_internal)
      render json: valid_526_response
    rescue ::EVSS::DisabilityCompensationForm::ServiceException, EVSS::ErrorMiddleware::EVSSError => e
      error_details = e.is_a?(EVSS::ErrorMiddleware::EVSSError) ? e.details : e.messages
      track_526_validation_errors(error_details)
      render json: { errors: format_526_errors(error_details) }, status: :unprocessable_entity
    rescue ::Common::Exceptions::GatewayTimeout,
           ::Timeout::Error,
           ::Faraday::TimeoutError,
           Breakers::OutageException => e
      req = { auth: auth_headers, form: form_attributes, source: source_name, auto_claim: auto_claim.as_json }
      PersonalInformationLog.create(
        error_class: "validate_form_526 #{e.class.name}", data: { request: req, error: e.try(:as_json) || e }
      )
      raise e
    end
    # rubocop:enable Metrics/MethodLength

    private

    def valid_526_response
      {
        data: {
          type: 'claims_api_auto_established_claim_validation',
          attributes: {
            status: 'valid'
          }
        }
      }.to_json
    end

    def format_526_errors(errors)
      errors.map do |error|
        { status: 422, detail: "#{error['key']} #{error['detail']}", source: error['key'] }
      end
    end

    def track_526_validation_errors(errors)
      StatsD.increment STATSD_VALIDATION_FAIL_KEY

      errors.each do |error|
        key = error['key']&.gsub(/\[(.*?)\]/, '')
        StatsD.increment STATSD_VALIDATION_FAIL_TYPE_KEY, tags: ["key: #{key}"]
      end
    end

    def unprocessable_response(e)
      log_message_to_sentry('Upload error in 526', :error, body: e.message)

      {
        errors: [{ status: 422, detail: e&.message, source: e&.key }]
      }.to_json
    end
  end
end
