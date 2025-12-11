# frozen_string_literal: true

require 'pdf_utilities/pdf_stamper'

module Pensions
  # @see ::VeteranFacingServices::NotificationCallback::SavedClaim
  class PDFStamper < ::PDFUtilities::PDFStamper
    # defined stamp sets to be used
    # override `timestamp` when calling `run` with the claim/attachment `created_at`
    STAMP_SETS = {
      pensions_received_at: [{
        text: 'VA.GOV',
        timestamp: nil,
        x: 5,
        y: 5
      }],
      pensions_generated_claim: [{
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
      }, {
        text: 'Application Submitted on va.gov',
        x: 440,
        y: 745,
        text_only: true, # passing as text only because we override how the date is stamped in this instance
        timestamp: nil,
        page_number: 0,
        size: 9,
        template: Pensions::PDF_PATH,
        multistamp: true
      }]
    }.freeze
  end
end
