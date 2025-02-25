# frozen_string_literal: true

require 'decision_review/utilities/pdf_validation/configuration'

module DecisionReview
  ##
  # Proxy Service for the Lighthouse PDF validation endpoint.
  #
  module PdfValidation
    class Service < Common::Client::Base
      include SentryLogging
      include Common::Client::Concerns::Monitoring

      configuration DecisionReview::PdfValidation::Configuration

      LH_ERROR_KEY = 'errors'
      LH_ERROR_DETAIL_KEY = 'detail'
      GENERIC_FAILURE_MESSAGE = 'Something went wrong...'

      def validate_pdf_with_lighthouse(file)
        perform(:post, 'uploads/validate_document',
                file.read,
                { 'Content-Type' => 'application/pdf', 'Transfer-Encoding' => 'chunked' })
      rescue Common::Client::Errors::ClientError => e
        emsg = 'Decision Review Upload failed PDF validation.'
        validation_failure_detail = e.body[LH_ERROR_KEY].pluck(LH_ERROR_DETAIL_KEY).join("\n")
        error_details = { message: emsg, error: e, validation_failure_detail: }
        ::Rails.logger.error(emsg, error_details)
        raise Common::Exceptions::UnprocessableEntity.new(
          detail: validation_failure_detail,
          source: 'FormAttachment.lighthouse_validation.invalid_pdf'
        )
      rescue => e
        emsg = 'Decision Review Upload failed with an unexpected failure case. Investigation Required.'
        error_details = { message: emsg, error: e }
        ::Rails.logger.error(emsg, error_details)
        raise Common::Exceptions::UnprocessableEntity.new(
          detail: GENERIC_FAILURE_MESSAGE,
          source: 'FormAttachment.lighthouse_validation.unknown_error'
        )
      end
    end
  end
end
