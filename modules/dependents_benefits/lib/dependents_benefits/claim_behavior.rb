# frozen_string_literal: true

require 'dependents_benefits/claim_behavior/submission_status'
require 'dependents_benefits/claim_behavior/form_validation'
require 'dependents_benefits/claim_behavior/form_type_checking'
require 'dependents_benefits/claim_behavior/veteran_information'

module DependentsBenefits
  ##
  # Shared validation and schema logic for DependentsBenefits claims
  # Include in SavedClaim subclasses that handle dependents benefits forms
  #
  module ClaimBehavior
    extend ActiveSupport::Concern

    include SubmissionStatus
    include FormValidation
    include FormTypeChecking
    include VeteranInformation

    # Generates a PDF representation of the claim form
    #
    # @param file_name [String, nil] Optional custom filename for the generated PDF
    # @param fill_options [Hash] Additional options for PDF generation
    # @param kwargs [Hash] Keyword arguments (form_id, student, created_at, etc.)
    # @return [String] Path to the generated PDF file
    def to_pdf(file_name = nil, fill_options = {}, **kwargs)
      options = fill_options.merge(kwargs)
      actual_file_name = kwargs.any? ? id.to_s : file_name
      DependentsBenefits::PdfFill::Filler.fill_form(self, actual_file_name, options)
    end

    private

    # Returns a memoized instance of the DependentsBenefits monitor
    #
    # @return [DependentsBenefits::Monitor] Monitor instance for tracking events and errors
    def monitor
      @monitor ||= DependentsBenefits::Monitor.new
    end
  end
end
