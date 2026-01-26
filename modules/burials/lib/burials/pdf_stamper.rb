# frozen_string_literal: true

require 'pdf_utilities/pdf_stamper'

module Burials
  # @see ::VeteranFacingServices::NotificationCallback::SavedClaim
  class PDFStamper < ::PDFUtilities::PDFStamper
    # rubocop:disable Metrics/MethodLength
    ##
    # Returns stamp sets to be used for PDF stamping.
    # Override `timestamp` when calling `run` with the claim/attachment `created_at`
    #
    # @return [Hash] Hash of stamp set identifiers to stamp configurations
    def self.stamp_sets
      {
        burials_received_at: [{
          text: 'VA.GOV',
          timestamp: nil,
          x: 5,
          y: 5
        }],
        burials_generated_claim: [{
          text: 'VA.GOV',
          timestamp: nil,
          x: 5,
          y: 5
        }, {
          text: 'FDC Reviewed - VA.gov Submission',
          timestamp: nil,
          x: 400,
          y: 815,
          text_only: true
        }, {
          text: 'Application Submitted on va.gov',
          x: 425,
          y: 720,
          text_only: true, # passing as text only because we override how the date is stamped in this instance
          timestamp: nil,
          page_number: 5,
          size: 9,
          template: Burials.pdf_path,
          multistamp: true
        }]
      }
    end
    # rubocop:enable Metrics/MethodLength
  end
end
