# frozen_string_literal: true

require 'lighthouse/benefits_claims/service'

module Lighthouse
  # Background job to verify Form 526 PDF presence in submitted disability compensation claims.
  #
  # This job checks whether a submitted Form 526 claim includes the expected PDF document
  # in the Lighthouse Benefits Claims Service. It queries the claim's supporting documents
  # and verifies that one of the expected Form 526 document type labels is present.
  #
  # @example Enqueue the job
  #   Lighthouse::Form526ClaimPdfCheck.perform_async(submission.id)
  #
  # @see Form526Submission
  # @see BenefitsClaims::Service
  class Form526ClaimPdfCheck
    include Sidekiq::Job

    # Expected document type labels for Form 526 PDFs in Lighthouse
    FORM_526_DOC_LABELS = [
      'VA 21-526 Veterans Application for Compensation or Pension',
      'VA 21-526EZ, Fully Developed Claim (Compensation)'
    ].freeze

    sidekiq_options retry: 3

    # Checks if a Form 526 PDF exists in the submitted claim's supporting documents.
    #
    # Retrieves the claim from Lighthouse Benefits Claims Service and inspects the
    # supporting documents for any document matching the expected Form 526 labels.
    # Logs the result including the submission ID, claim ID, and whether the PDF was found.
    #
    # @param submission_id [Integer] The {Form526Submission} id
    # @return [void]
    # @raise [ActiveRecord::RecordNotFound] if the submission doesn't exist
    def perform(submission_id)
      submission = Form526Submission.find(submission_id)
      submitted_claim_id = submission.submitted_claim_id

      has_pdf = claim_has_526_pdf?(submission, submitted_claim_id)

      Rails.logger.info(
        'Form526ClaimPdfCheck result',
        {
          form526_submission_id: submission_id,
          submitted_claim_id:,
          has_pdf_in_claim: has_pdf
        }
      )
    end

    private

    # Determines if the claim contains a Form 526 PDF document.
    #
    # Calls the Lighthouse Benefits Claims Service to retrieve the claim details
    # and checks if any supporting document has a label matching the expected
    # Form 526 document types.
    #
    # @param submission [Form526Submission] The form submission record
    # @param submitted_claim_id [Integer] The claim ID in Lighthouse
    # @return [Boolean] true if a Form 526 PDF is found, false otherwise
    def claim_has_526_pdf?(submission, submitted_claim_id)
      icn = submission.account.icn
      service = BenefitsClaims::Service.new(icn)
      raw_response = service.get_claim(submitted_claim_id)
      raw_response_body = raw_response.is_a?(String) ? JSON.parse(raw_response) : raw_response

      supporting_documents = raw_response_body.dig('data', 'attributes', 'supportingDocuments') || []
      supporting_documents.any? { |doc| FORM_526_DOC_LABELS.include?(doc['documentTypeLabel']) }
    end
  end
end
