# frozen_string_literal: true

module DependentsBenefits
  module ClaimBehavior
    # Methods for determining vbms types
    module VBMSInformation
      extend ActiveSupport::Concern

      # flagged options for chile removal
      REMOVE_CHILD_OPTIONS = %w[
        report_child18_or_older_is_not_attending_school
        report_stepchild_not_in_household
        report_marriage_of_child_under18
      ].freeze
      # marraige type list
      MARRIAGE_TYPES = %w[COMMON-LAW TRIBAL PROXY OTHER].freeze
      # relationship list
      RELATIONSHIPS = %w[CHILD DEPENDENT_PARENT].freeze

      # parse vbms claim information for submission to FormsAPI and other systems
      def get_claim_information(user = nil)
        dependents_app = parsed_form['dependents_application']
        selectable_options = parsed_form['view:selectable686_options']

        @claim_name = '130 - Automated Dependency 686c'
        @claim_label = '130DPNEBNADJ'
        @proc_state = 'Ready'

        set_proc_state(selectable_options, dependents_app)
        set_claim_type(selectable_options, user)

        {
          proc_state: @proc_state,
          note_text: @note_text,
          claim_name: @claim_name,
          claim_label: @claim_label,
          participant_id: user&.participant_id
        }
      end

      private

      # determine if the claim needs to be processed as MANUAL
      def set_proc_state(selectable_options, dependents_app)
        # search through the "selectable_options" hash and check if any of the "REMOVE_CHILD_OPTIONS" are set to true
        if REMOVE_CHILD_OPTIONS.any? { |child_option| selectable_options[child_option] }
          # find which one of the remove child options is selected, and set the manual_vagov reason for that option
          selectable_options.each do |remove_option, is_selected|
            return set_to_manual_vagov(remove_option) if REMOVE_CHILD_OPTIONS.any?(remove_option) && is_selected
          end
        end

        # if the user is adding a spouse and the marriage type !== CEREMONIAL, set the status to manual
        if selectable_options['add_spouse'] && MARRIAGE_TYPES.any? do |m|
             current_marriage_info = dependents_app['current_marriage_information']
             m == current_marriage_info['type_of_marriage']
           end
          return set_to_manual_vagov('add_spouse')
        end

        # search through the array of "deaths" and check if the dependent_type = "CHILD" or "DEPENDENT_PARENT"
        if selectable_options['report_death'] && dependents_app['deaths']&.any? do |h|
             RELATIONSHIPS.include?(h['dependent_type'])
           end
          return set_to_manual_vagov('report_death')
        end

        return set_to_manual_vagov('report674') if selectable_options['report674']

        @proc_state = 'Started'
      end

      # set the proc state to MANUAL_VAGOV and populate note text
      def set_to_manual_vagov(reason_code)
        @note_text = 'Claim set to manual by VA.gov: This application needs manual review because a 686 was submitted '

        case reason_code
        when 'report_death'
          @note_text += 'for removal of a child/dependent parent due to death.'
        when 'add_spouse'
          @note_text += 'to add a spouse due to civic/non-ceremonial marriage.'
        when 'report_stepchild_not_in_household'
          @note_text += 'for removal of a step-child that has left household.'
        when 'report_marriage_of_child_under18'
          @note_text += 'for removal of a married minor child.'
        when 'report_child18_or_older_is_not_attending_school'
          @note_text += 'for removal of a schoolchild over 18 who has stopped attending school.'
        when 'report674'
          @note_text += 'along with a 674.'
        end

        @proc_state = 'MANUAL_VAGOV'
      end

      # rubocop:disable Metrics/MethodLength
      # the default claim type is 130DPNEBNADJ (eBenefits Dependency Adjustment)
      def set_claim_type(selectable_options, user = nil)
        # selectable_options is a hash of boolean values (ex. 'report_divorce' => false)
        # if any of the dependent_removal_options in selectable_options is set to true, we are removing a dependent
        removing_dependent = false
        if Flipper.enabled?(:dependents_removal_check)
          dependent_removal_options = REMOVE_CHILD_OPTIONS.dup << 'report_death' << 'report_divorce'
          removing_dependent = dependent_removal_options.any? { |option| selectable_options[option] }
        end

        # we only need to do a pension check if we are removing a dependent or we have set the status to manual
        receiving_pension = false
        if Flipper.enabled?(:dependents_pension_check) && user && (removing_dependent || @proc_state == 'MANUAL_VAGOV')
          bid_service = BID::Awards::Service.new(user)
          pension_response = bid_service.get_awards_pension
          receiving_pension = pension_response.body['awards_pension']['is_in_receipt_of_pension']
        end

        # if we are setting the claim to be manually reviewed, then exception/rejection labels should be used
        if @proc_state == 'MANUAL_VAGOV'
          if removing_dependent && receiving_pension
            @claim_name = 'PMC - Self Service - Removal of Dependent Exceptn'
            @claim_label = '130SSRDPMCE'
          elsif removing_dependent
            @claim_name = 'Self Service - Removal of Dependent Exception'
            @claim_label = '130SSRDE'
          elsif receiving_pension
            @claim_name = 'PMC eBenefits Dependency Adjustment Reject'
            @claim_label = '130DAEBNPMCR'
          else
            @claim_name = 'eBenefits Dependency Adjustment Reject'
            @claim_label = '130DPEBNAJRE'
          end
        elsif removing_dependent
          if receiving_pension
            @claim_name = 'PMC - Self Service - Removal of Dependent'
            @claim_label = '130SSRDPMC'
          else
            @claim_name = 'Self Service - Removal of Dependent'
            @claim_label = '130SSRD'
          end
        end
      end
      # rubocop:enable Metrics/MethodLength
    end
  end
end
