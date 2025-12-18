# frozen_string_literal: true

require_relative 'claim_behavior/submission_status'
require_relative 'claim_behavior/form_validation'
require_relative 'claim_behavior/form_type_checking'
require_relative 'claim_behavior/veteran_information'

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
    # @return [String] Path to the generated PDF file
    def to_pdf(file_name = nil)
      DependentsBenefits::PdfFill::Filler.fill_form(self, file_name)
    end

    private

    # Returns a memoized instance of the DependentsBenefits monitor
    #
    # @return [DependentsBenefits::Monitor] Monitor instance for tracking events and errors
    def monitor
      @monitor ||= DependentsBenefits::Monitor.new
    end

    # Returns the StatsD key prefix for tracking claim metrics
    #
    # @return [String] The stats key prefix 'api.dependents_claim'
    def stats_key
      'api.dependents_claim'
    end
  end
end
