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
    # @param file_name_or_options [String, Hash, nil] Either a filename string or hash with form_id/student options
    # @param fill_options [Hash] Additional options for PDF generation (student data, created_at, etc.)
    # @return [String] Path to the generated PDF file
    def to_pdf(file_name_or_options = nil, fill_options = {})
      if file_name_or_options.is_a?(Hash)
        # Called with keyword args like: to_pdf(form_id: '21-674-V2', student: {...})
        fill_options = file_name_or_options
        file_name = id.to_s
      else
        # Called with positional args like: to_pdf('12345', {student: {...}})
        file_name = file_name_or_options
      end

      DependentsBenefits::PdfFill::Filler.fill_form(self, file_name, fill_options)
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
