# frozen_string_literal: true

require 'dependents_benefits/claim_behavior'

module DependentsBenefits
  # DependentsBenefit 21-674 Active::Record
  # @see app/model/saved_claim
  class SchoolAttendanceApproval < ::SavedClaim
    include DependentsBenefits::ClaimBehavior

    # DependentsBenefit Form ID
    FORM = DependentsBenefits::SCHOOL_ATTENDANCE_APPROVAL

    # Returns the business line associated with this process
    #
    # @return [String]
    def business_line
      'CMP'
    end

    # the VBMS document type for _this_ claim type
    def document_type
      142
    end

    # Generates a PDF from the saved claim data
    #
    # @param file_name [String, nil] Optional name for the output PDF file
    # @param fill_options [Hash] Additional options for PDF generation
    # @return [String] Path to the generated PDF file
    #
    def to_pdf(file_name = nil, fill_options = {})
      ::PdfFill::Filler.fill_form(self, file_name, fill_options)
    end
  end
end
