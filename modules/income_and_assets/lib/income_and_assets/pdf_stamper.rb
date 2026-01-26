# frozen_string_literal: true

require 'pdf_utilities/pdf_stamper'

module IncomeAndAssets
  # @see ::VeteranFacingServices::NotificationCallback::SavedClaim
  class PDFStamper < ::PDFUtilities::PDFStamper
    # defined stamp sets to be used
    # override `timestamp` when calling `run` with the claim/attachment `created_at`
    STAMP_SETS = {
      income_and_assets_received_at: [{
        text: 'VA.GOV',
        timestamp: nil,
        x: 5,
        y: 5
      }],
      income_and_assets_generated_claim: [{
        text: 'VA.GOV',
        timestamp: nil,
        x: 5,
        y: 5
      }, {
        text: 'FDC Reviewed - VA.gov Submission',
        timestamp: nil,
        x: 430,
        y: 820,
        text_only: true
      }]
    }.freeze
  end
end
