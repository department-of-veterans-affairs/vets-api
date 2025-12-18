# frozen_string_literal: true

module DependentsBenefits
  module ClaimBehavior
    ##
    # Methods for checking form types and pension-related logic
    #
    module FormTypeChecking
      extend ActiveSupport::Concern

      # Fields indicating that a 686 dependent claim is being made
      DEPENDENT_CLAIM_FLOWS = %w[
        report_death
        report_divorce
        add_child
        report_stepchild_not_in_household
        report_marriage_of_child_under18
        child_marriage
        report_child18_or_older_is_not_attending_school
        add_spouse
        add_disabled_child
      ].freeze

      # Checks if the claim contains a submittable 686 form
      #
      # Determines whether any of the dependent claim flows selected in the form
      # match the defined DEPENDENT_CLAIM_FLOWS for form 686
      #
      # @return [Boolean] true if the form includes valid 686 claim flows, false otherwise
      def submittable_686?
        DEPENDENT_CLAIM_FLOWS.any? { |flow| parsed_form['view:selectable686_options'].include?(flow) }
      end

      # Checks if the claim contains a submittable 674 form
      #
      # Determines whether the report674 option is selected in the form,
      # indicating a student dependency claim
      #
      # @return [Boolean, nil] true if report674 is selected, false/nil otherwise
      def submittable_674?
        parsed_form.dig('view:selectable686_options', 'report674')
      end

      # Checks if claim is pension related submission
      #
      # @return [Boolean] true if the submission is pension related, false otherwise
      def pension_related_submission?
        return false unless Flipper.enabled?(:va_dependents_net_worth_and_pension)

        # We can determine pension-related submission by checking if
        # household income or student income info was asked on the form
        household_income_present = parsed_form['dependents_application']&.key?('household_income')
        student_income_present = parsed_form.dig('dependents_application', 'student_information')&.any? do |student|
          student&.key?('student_networth_information')
        end

        !!(household_income_present || student_income_present)
      end
    end
  end
end
