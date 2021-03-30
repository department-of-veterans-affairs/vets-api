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

module BGS
  class Form686c
    REMOVE_CHILD_OPTIONS = %w[report_child18_or_older_is_not_attending_school
                              report_stepchild_not_in_household
                              report_marriage_of_child_under18].freeze

    def initialize(user)
      @user = user
    end

    def submit(payload)
      vnp_proc_state_type_cd = get_state_type(payload)
      proc_id = create_proc_id_and_form(vnp_proc_state_type_cd)
      veteran = VnpVeteran.new(proc_id: proc_id, payload: payload, user: @user, claim_type: '130DPNEBNADJ').create

      process_relationships(proc_id, veteran, payload)

      vnp_benefit_claim = VnpBenefitClaim.new(proc_id: proc_id, veteran: veteran, user: @user)
      vnp_benefit_claim_record = vnp_benefit_claim.create

      benefit_claim_record = BenefitClaim.new(
        args: {
          vnp_benefit_claim: vnp_benefit_claim_record,
          veteran: veteran,
          user: @user,
          proc_id: proc_id,
          end_product_name: '130 - Automated Dependency 686c',
          end_product_code: '130DPNEBNADJ'
        }
      ).create

      vnp_benefit_claim.update(benefit_claim_record, vnp_benefit_claim_record)
      proc_state = vnp_proc_state_type_cd == 'MANUAL_VAGOV' ? vnp_proc_state_type_cd : 'Ready'
      bgs_service.update_proc(proc_id, proc_state: proc_state)
    end

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
      return 'MANUAL_VAGOV' if REMOVE_CHILD_OPTIONS.any? { |child_option| selectable_options[child_option] }

      # search through the array of "deaths" and check if the dependent_type = "CHILD" or "DEPENDENT_PARENT"
      if selectable_options['report_death']
        relationships = %w[CHILD DEPENDENT_PARENT]
        return 'MANUAL_VAGOV' if dependents_app['deaths'].any? { |h| relationships.include?(h['dependent_type']) }
      end

      'Started'
    end

    def bgs_service
      BGS::Service.new(@user)
    end
  end
end
