# frozen_string_literal: true

require_relative 'benefit_claim'
require_relative 'dependents'
require_relative 'marriages'
require_relative 'service'
require_relative 'student_school'
require_relative 'vnp_benefit_claim'
require_relative 'vnp_relationships'
require_relative 'vnp_veteran'
require_relative 'children'
require_relative '../bid/awards/service'

module BGS
  class Form686c
    include SentryLogging

    REMOVE_CHILD_OPTIONS = %w[report_child18_or_older_is_not_attending_school
                              report_stepchild_not_in_household
                              report_marriage_of_child_under18].freeze

    def initialize(user)
      @user = user
      @end_product_name = '130 - Automated Dependency 686c'
      @end_product_code = '130DPNEBNADJ'
      @proc_state = 'Ready'
      @note_text = nil
    end

    # rubocop:disable Metrics/MethodLength
    def submit(payload)
      vnp_proc_state_type_cd = get_state_type(payload)
      proc_id = create_proc_id_and_form(vnp_proc_state_type_cd)
      veteran = VnpVeteran.new(proc_id: proc_id, payload: payload, user: @user, claim_type: '130DPNEBNADJ').create

      process_relationships(proc_id, veteran, payload)

      vnp_benefit_claim = VnpBenefitClaim.new(proc_id: proc_id, veteran: veteran, user: @user)
      vnp_benefit_claim_record = vnp_benefit_claim.create

      set_claim_type(vnp_proc_state_type_cd)

      # temporary logging to troubleshoot
      log_message_to_sentry("#{proc_id} - #{@end_product_code}", :warn, '', { team: 'vfs-ebenefits' })

      benefit_claim_record = BenefitClaim.new(
        args: {
          vnp_benefit_claim: vnp_benefit_claim_record,
          veteran: veteran,
          user: @user,
          proc_id: proc_id,
          end_product_name: @end_product_name,
          end_product_code: @end_product_code
        }
      ).create

      vnp_benefit_claim.update(benefit_claim_record, vnp_benefit_claim_record)
      prep_manual_claim(benefit_claim_record[:benefit_claim_id]) if vnp_proc_state_type_cd == 'MANUAL_VAGOV'
      bgs_service.update_proc(proc_id, proc_state: @proc_state)
    end
    # rubocop:enable Metrics/MethodLength

    private

    def process_relationships(proc_id, veteran, payload)
      dependents = Dependents.new(proc_id: proc_id, payload: payload, user: @user).create_all
      marriages = Marriages.new(proc_id: proc_id, payload: payload, user: @user).create_all
      children = Children.new(proc_id: proc_id, payload: payload, user: @user).create_all

      veteran_dependents = dependents + marriages + children[:dependents]

      VnpRelationships.new(
        proc_id: proc_id,
        veteran: veteran,
        dependents: veteran_dependents,
        step_children: children[:step_children],
        user: @user
      ).create_all
    end

    def create_proc_id_and_form(vnp_proc_state_type_cd)
      vnp_response = bgs_service.create_proc(proc_state: vnp_proc_state_type_cd)
      bgs_service.create_proc_form(
        vnp_response[:vnp_proc_id],
        '21-686c'
      )

      vnp_response[:vnp_proc_id]
    end

    def get_state_type(payload)
      selectable_options = payload['view:selectable686_options']
      dependents_app = payload['dependents_application']

      # search through the "selectable_options" hash and check if any of the "REMOVE_CHILD_OPTIONS" are set to true
      if REMOVE_CHILD_OPTIONS.any? { |child_option| selectable_options[child_option] }
        # find which one of the remove child options is selected, and set the reject reason for that option
        selectable_options.each do |remove_option, is_selected|
          return reject_claim(remove_option) if REMOVE_CHILD_OPTIONS.any?(remove_option) && is_selected
        end
      end

      # if the user is adding a spouse and the marriage type is anything other than CEREMONIAL, set the status to manual
      if selectable_options['add_spouse']
        marriage_types = %w[COMMON-LAW TRIBAL PROXY OTHER]
        if marriage_types.any? { |m| m == dependents_app['current_marriage_information']['type'] }
          return reject_claim('add_spouse')
        end
      end

      # search through the array of "deaths" and check if the dependent_type = "CHILD" or "DEPENDENT_PARENT"
      if selectable_options['report_death']
        relationships = %w[CHILD DEPENDENT_PARENT]
        if dependents_app['deaths'].any? { |h| relationships.include?(h['dependent_type']) }
          return reject_claim('report_death')
        end
      end

      'Started'
    end

    # the default claim type is 130DPNEBNADJ (eBenefits Dependency Adjustment)
    # if we are setting the claim to be manually reviewed
    # and the Veteran is currently receiving pension benefits
    # set the claim type to 130DAEBNPMCR (PMC eBenefits Dependency Adjustment Reject)
    # else use 130DPEBNAJRE (eBenefits Dependency Adjustment Reject)
    def set_claim_type(proc_state)
      if proc_state == 'MANUAL_VAGOV'
        receiving_pension = false

        if Flipper.enabled?(:dependents_pension_check)
          pension_response = bid_service.get_awards_pension
          receiving_pension = pension_response.body['awards_pension']['is_in_receipt_of_pension']
        end

        if receiving_pension
          @end_product_name = 'PMC eBenefits Dependency Adjustment Reject'
          @end_product_code = '130DAEBNPMCR'
        else
          @end_product_name = 'eBenefits Dependency Adjustment Reject'
          @end_product_code = '130DPEBNAJRE'
        end
      end
    end

    def bgs_service
      BGS::Service.new(@user)
    end

    def bid_service
      BID::Awards::Service.new(@user)
    end

    def prep_manual_claim(benefit_claim_id)
      @proc_state = 'MANUAL_VAGOV'

      bgs_service.create_note(benefit_claim_id, @note_text)
    end

    def reject_claim(reason_code)
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
      end

      'MANUAL_VAGOV'
    end
  end
end
