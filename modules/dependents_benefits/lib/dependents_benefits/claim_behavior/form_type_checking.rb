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

      # Constants for form IDs
      # 686c only
      FORM686 = '21-686c'
      # 674 only
      FORM674 = '21-674'
      # Both 686c and 674
      FORM_COMBO = '686c-674'

      # Checks if the claim contains a submittable 686 form
      #
      # Determines whether any of the dependent claim flows selected in the form
      # match the defined DEPENDENT_CLAIM_FLOWS for form 686
      #
      # @return [Boolean] true if the form includes valid 686 claim flows, false otherwise
      def submittable_686?
        # checking key and value just avoids inconsistencies in the mock data or from FE submission
        DEPENDENT_CLAIM_FLOWS.any? do |flow|
          parsed_form['view:selectable686_options'].include?(flow) && parsed_form['view:selectable686_options'][flow]
        end
      end

      # Checks if the claim contains a submittable 674 form
      #
      # Determines whether the report674 option is selected in the form,
      # indicating a student dependency claim
      #
      # @return [Boolean, nil] true if report674 is selected, false/nil otherwise
      def submittable_674?
        parsed_form['view:selectable686_options'].include?('report674') &&
          parsed_form['view:selectable686_options']['report674']
      end

      # Determines the claim form type based on included submittable forms
      #
      # @return [String, nil] the form type: '21-686c', '21-674', or '686c-674'; nil if unknown
      def claim_form_type
        return FORM_COMBO if submittable_686? && submittable_674?
        return FORM686 if submittable_686?

        FORM674 if submittable_674?
      rescue => e
        monitor.track_unknown_claim_type(
          'Unknown Dependents form type for claim',
          claim_id: id,
          error: e
        )
        nil
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
