# frozen_string_literal: true

require 'vets/shared_logging'

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
    include Vets::SharedLogging

    attr_reader :user, :saved_claim, :proc_id, :claim_type_end_product

    REMOVE_CHILD_OPTIONS = %w[report_child18_or_older_is_not_attending_school
                              report_stepchild_not_in_household
                              report_marriage_of_child_under18].freeze
    MARRIAGE_TYPES = %w[COMMON-LAW TRIBAL PROXY OTHER].freeze
    RELATIONSHIPS = %w[CHILD DEPENDENT_PARENT].freeze

    def initialize(user, saved_claim, options = {})
      @user = user
      @saved_claim = saved_claim
      @end_product_name = '130 - Automated Dependency 686c'
      @end_product_code = '130DPNEBNADJ'
      @proc_state = 'Ready'
      @note_text = nil
      @proc_id = options[:proc_id] if options.present?
      @claim_type_end_product = options[:claim_type_end_product]
    end

    # rubocop:disable Metrics/MethodLength
    def submit(payload)
      vnp_proc_state_type_cd = get_state_type(payload)
      @proc_id = create_proc_id_and_form(vnp_proc_state_type_cd) if @proc_id.nil?
      veteran = VnpVeteran.new(proc_id:, payload:, user:, claim_type: '130DPNEBNADJ', claim_type_end_product:).create

      process_relationships(@proc_id, veteran, payload)

      vnp_benefit_claim = VnpBenefitClaim.new(proc_id:, veteran:, user:)
      vnp_benefit_claim_record = vnp_benefit_claim.create

      set_claim_type(vnp_proc_state_type_cd, payload['view:selectable686_options'])

      benefit_claim_record = BenefitClaim.new(
        args: {
          vnp_benefit_claim: vnp_benefit_claim_record,
          veteran:,
          user:,
          proc_id:,
          end_product_name: @end_product_name,
          end_product_code: @end_product_code
        }
      ).create

      begin
        benefit_claim_id = benefit_claim_record[:benefit_claim_id]
        vnp_benefit_claim.update(benefit_claim_record, vnp_benefit_claim_record)
        if vnp_proc_state_type_cd == 'MANUAL_VAGOV'
          prep_manual_claim(benefit_claim_id)
        else
          monitor.track_event('info',
                              "686C Saved Claim submitted automatically to RBPS with proc_state of #{@proc_state}",
                              "#{stats_key}.automatic", { proc_id: @proc_id, automatic: true })
        end
        bgs_service.update_proc(@proc_id, proc_state: @proc_state)
      rescue => e
        monitor.track_event('warn', 'BGS::Form686c.submit failed after creating benefit claim in BGS',
                            "#{stats_key}.failure", { user_uuid: user.uuid, error: e.message })
      end
    end
    # rubocop:enable Metrics/MethodLength

    private

    def process_relationships(proc_id, veteran, payload)
      dependents = Dependents.new(proc_id:, payload:, user: @user).create_all
      marriages = Marriages.new(proc_id:, payload:, user: @user).create_all
      children = Children.new(proc_id:, payload:, user: @user).create_all

      veteran_dependents = dependents + marriages + children[:dependents]

      VnpRelationships.new(
        proc_id:,
        veteran:,
        dependents: veteran_dependents,
        step_children: children[:step_children],
        user: @user
      ).create_all
    end

    def create_proc_id_and_form(vnp_proc_state_type_cd)
      if @proc_id.nil?
        vnp_response = bgs_service.create_proc(proc_state: vnp_proc_state_type_cd)
        @proc_id = vnp_response[:vnp_proc_id]
      end

      bgs_service.create_proc_form(
        @proc_id,
        '21-686c'
      )

      @proc_id
    end

    def get_state_type(payload)
      selectable_options = payload['view:selectable686_options']
      dependents_app = payload['dependents_application']

      # search through the "selectable_options" hash and check if any of the "REMOVE_CHILD_OPTIONS" are set to true
      if REMOVE_CHILD_OPTIONS.any? { |child_option| selectable_options[child_option] }
        # find which one of the remove child options is selected, and set the manual_vagov reason for that option
        selectable_options.each do |remove_option, is_selected|
          return set_to_manual_vagov(remove_option) if REMOVE_CHILD_OPTIONS.any?(remove_option) && is_selected
        end
      end

      # if the user is adding a spouse and the marriage type is anything other than CEREMONIAL, set the status to manual
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

      'Started'
    end

    # rubocop:disable Metrics/MethodLength
    # the default claim type is 130DPNEBNADJ (eBenefits Dependency Adjustment)
    def set_claim_type(proc_state, selectable_options)
      # selectable_options is a hash of boolean values (ex. 'report_divorce' => false)
      # if any of the dependent_removal_options in selectable_options is set to true, we are removing a dependent
      removing_dependent = false
      if Flipper.enabled?(:dependents_removal_check)
        dependent_removal_options = REMOVE_CHILD_OPTIONS.dup << 'report_death' << 'report_divorce'
        removing_dependent = dependent_removal_options.any? { |option| selectable_options[option] }
      end

      # we only need to do a pension check if we are removing a dependent or we have set the status to manual
      receiving_pension = false
      if Flipper.enabled?(:dependents_pension_check) && (removing_dependent || proc_state == 'MANUAL_VAGOV')
        pension_response = bid_service.get_awards_pension
        receiving_pension = pension_response.body['awards_pension']['is_in_receipt_of_pension']
      end

      # if we are setting the claim to be manually reviewed, then exception/rejection labels should be used
      if proc_state == 'MANUAL_VAGOV'
        if removing_dependent && receiving_pension
          @end_product_name = 'PMC - Self Service - Removal of Dependent Exceptn'
          @end_product_code = '130SSRDPMCE'
        elsif removing_dependent
          @end_product_name = 'Self Service - Removal of Dependent Exception'
          @end_product_code = '130SSRDE'
        elsif receiving_pension
          @end_product_name = 'PMC eBenefits Dependency Adjustment Reject'
          @end_product_code = '130DAEBNPMCR'
        else
          @end_product_name = 'eBenefits Dependency Adjustment Reject'
          @end_product_code = '130DPEBNAJRE'
        end
      elsif removing_dependent
        if receiving_pension
          @end_product_name = 'PMC - Self Service - Removal of Dependent'
          @end_product_code = '130SSRDPMC'
        else
          @end_product_name = 'Self Service - Removal of Dependent'
          @end_product_code = '130SSRD'
        end
      end
    end
    # rubocop:enable Metrics/MethodLength

    def bgs_service
      BGS::Service.new(@user)
    end

    def bid_service
      BID::Awards::Service.new(@user)
    end

    def prep_manual_claim(benefit_claim_id)
      @proc_state = 'MANUAL_VAGOV'
      if @saved_claim.submittable_674?
        monitor.track_event('info', @note_text, "#{stats_key}.manual.combo",
                            { proc_id: @proc_id, manual: true, combination_claim: true })
      else
        monitor.track_event('info', @note_text, "#{stats_key}.manual", { proc_id: @proc_id, manual: true })
      end
      bgs_service.create_note(benefit_claim_id, @note_text)
    end

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

      'MANUAL_VAGOV'
    end

    def stats_key
      'bgs.form686c'
    end

    def monitor
      @monitor ||= ::Dependents::Monitor.new(@saved_claim.id)
    end
  end
end
