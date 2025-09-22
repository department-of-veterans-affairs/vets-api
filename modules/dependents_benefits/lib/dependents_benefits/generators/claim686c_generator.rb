# frozen_string_literal: true

require 'dependents_benefits/generators/dependent_claim_generator'

module DependentsBenefits
  module Generators
    ##
    # Generator for creating VA Form 21-686c claims from combined 686c-674 form data
    #
    # VA Form 21-686c: "Application Request to Add and/or Remove Dependents"
    # Use this form to submit a claim for additional benefits for a dependent,
    # or to request to remove a dependent from your benefits.
    #
    # Extracts only the dependent-related data for the 686c claim
    #
    class Claim686cGenerator < Generators::DependentClaimGenerator
      private

      FORM_KEYS = ['veteran_information', 'view:selectable_686_options',
                   'statement_of_truth_signature', 'statement_of_truth_certified'].freeze
      APPLICATION_KEYS = %w[
        veteran_contact_information
        household_income
        spouse_information
        current_marriage_information
        does_live_with_spouse
        veteran_marriage_history
        spouse_marriage_history
        children_to_add
        report_divorce
        step_children
        deaths
        child_marriage
        child_stopped_attending_school
      ].freeze

      ##
      # Extract form data relevant to VA Form 21-686c claims (dependent data)
      # Based on the partitioned_686_674_params method from SavedClaim::DependencyClaim
      #
      # @return [Hash] The form data containing only 21-686c-relevant information
      #
      def extract_form_data
        dependent_data = form_data.deep_dup
        form_686c_data = dependent_data.slice(*FORM_KEYS)

        return form_686c_data unless dependent_data['dependents_application']

        form_686c_data['dependents_application'] = dependent_data['dependents_application'].slice(
          *APPLICATION_KEYS
        )

        form_686c_data
      end

      def claim_class
        AddRemoveDependent
      end
    end
  end
end
