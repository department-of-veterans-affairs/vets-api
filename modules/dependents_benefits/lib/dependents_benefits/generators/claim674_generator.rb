# frozen_string_literal: true

require 'dependents_benefits/generators/dependent_claim_generator'

module DependentsBenefits
  ##
  # Generator for creating VA Form 21-674 claims from combined 686c-674 form data
  #
  # VA Form 21-674: "Request for Approval of School Attendance"
  # Use this form when claiming benefits for a child who is at least 18 years old,
  # but under 23, and attending school.
  #
  # Extracts only the required data for the 674 claim for a specific student
  #
  class Claim674Generator < DependentClaimGenerator
    def initialize(form_data, parent_id, student_data)
      super(form_data, parent_id)
      @student_data = student_data
    end

    private

    attr_reader :student_data

    ##
    # Extract form data relevant to VA Form 21-674 claims (college student data)
    # Based on the partitioned_686_674_params method from SavedClaim::DependencyClaim
    # This creates a claim for a specific individual student
    #
    # @return [Hash] The form data containing only 21-674-relevant information for one student
    #
    def extract_form_data
      dependent_data = form_data.deep_dup

      form_674_data = dependent_data['dependents_application']&.slice(
        'veteran_contact_information',
        'view:completed_child_stopped_attending_school',
        'view:add_or_remove_dependents',
        'view:remove_dependent_options',
        'view:selectable686_options',
        'child_stopped_attending_school',
        'veteran_information',
        'days_till_expires',
        'privacy_agreement_accepted'
      ) || {}

      dependent_data
        .slice('veteran_information', 'statement_of_truth_signature', 'statement_of_truth_certified')
        .merge('dependents_application' => form_674_data.merge('student_information' => student_data))
    end

    # Return the form_id for VA Form 21-674 claims
    #
    # @return [String] The VA Form 21-674 form_id
    #
    def form_id
      '21-674'
    end
  end
end
