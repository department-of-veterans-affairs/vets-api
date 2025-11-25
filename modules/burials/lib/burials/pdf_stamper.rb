# frozen_string_literal: true

require 'pdf_utilities/pdf_stamper'

module Burials
  # @see ::VeteranFacingServices::NotificationCallback::SavedClaim
  class PDFStamper < ::PDFUtilities::PDFStamper

    # defined stamp sets to be used
    # override `timestamp` when calling `run` with the claim/attachment `created_at`
    STAMP_SETS = {
      burials_received_at: [{
        text: 'VA.GOV',
        timestamp: nil,
        x: 5,
        y: 5
      }],
      burials_generated_pdf: [{
        text: 'VA.GOV',
        timestamp: nil,
        x: 5,
        y: 5
      }, {
        text: 'FDC Reviewed - VA.gov Submission',
        timestamp: nil,
        x: 400,
        y: 770,
        text_only: true
      }, {
        text: 'Application Submitted on va.gov',
        x: 425,
        y: 675,
        text_only: true, # passing as text only because we override how the date is stamped in this instance
        timestamp: nil,
        page_number: 5,
        size: 9,
        template: Burials::PDF_PATH,
        multistamp: true
      }]
    }.freeze

  end
end
