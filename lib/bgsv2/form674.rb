# frozen_string_literal: true

require_relative 'benefit_claim'
require_relative 'dependents'
require_relative 'service'
require_relative 'student_school'
require_relative 'vnp_benefit_claim'
require_relative 'vnp_relationships'
require_relative 'vnp_veteran'
require_relative 'dependent_higher_ed_attendance'
require_relative '../bid/awards/service'

module BGSV2
  class Form674
    include SentryLogging

    attr_reader :user, :saved_claim, :proc_id

    def initialize(user, saved_claim)
      @user = user
      @saved_claim = saved_claim
      @proc_id = vnp_proc_id(saved_claim)
      @end_product_name = '130 - Automated School Attendance 674'
      @end_product_code = '130SCHATTEBN'
      @proc_state = 'Ready'
    end

    def submit(payload)
      veteran = VnpVeteran.new(proc_id:, payload:, user:, claim_type: '130SCHATTEBN').create

      process_relationships(proc_id, veteran, payload)

      vnp_benefit_claim = VnpBenefitClaim.new(proc_id:, veteran:, user:)
      vnp_benefit_claim_record = vnp_benefit_claim.create

      # we are TEMPORARILY always setting to MANUAL_VAGOV for 674
      if @saved_claim.submittable_686?
        set_claim_type('MANUAL_VAGOV')
        @proc_state = 'MANUAL_VAGOV'
      end

      # temporary logging to troubleshoot
      log_message_to_sentry("#{proc_id} - #{@end_product_code}", :warn, '', { team: 'vfs-ebenefits' })

      Rails.logger.info('21-674 Automatic Claim Prior to submission', { saved_claim_id: @saved_claim.id, proc_id: @proc_id }) if @proc_state == 'Ready' # rubocop:disable Layout/LineLength
      benefit_claim_record = BenefitClaim.new(args: benefit_claim_args(vnp_benefit_claim_record, veteran)).create
      Rails.logger.info("21-674 Automatic Benefit Claim successfully created through BGS: #{benefit_claim_record[:benefit_claim_id]}", { saved_claim_id: @saved_claim.id, proc_id: @proc_id }) if @proc_state == 'Ready' # rubocop:disable Layout/LineLength

      begin
        vnp_benefit_claim.update(benefit_claim_record, vnp_benefit_claim_record)
        log_claim_status(benefit_claim_record, proc_id)
      rescue
        log_submit_failure(error)
      end
    end

    private

    def benefit_claim_args(vnp_benefit_claim_record, veteran)
      {
        vnp_benefit_claim: vnp_benefit_claim_record,
        veteran:,
        user:,
        proc_id:,
        end_product_name: @end_product_name,
        end_product_code: @end_product_code
      }
    end

    def log_claim_status(benefit_claim_record, proc_id)
      if @proc_state == 'MANUAL_VAGOV'
        if @saved_claim.submittable_686?
          Rails.logger.info('21-674 Combination 686C-674 claim set to manual by VA.gov: This
                            application needs manual review because a 674 was submitted alongside a 686c.',
                            { saved_claim_id: @saved_claim.id, proc_id: @proc_id, manual: true,
                              combination_claim: true })
          StatsD.increment("#{stats_key}.manual.combo")
        else
          Rails.logger.info('21-674 Claim set to manual by VA.gov: This application needs manual review.',
                            { saved_claim_id: @saved_claim.id, proc_id: @proc_id, manual: true })
          StatsD.increment("#{stats_key}.manual")
        end
        # keep bgs note the same
        note_text = 'Claim set to manual by VA.gov: This application needs manual review because a 674 was submitted.'
        bgs_service.create_note(benefit_claim_record[:benefit_claim_id], note_text)

        bgs_service.update_proc(proc_id, proc_state: 'MANUAL_VAGOV')
      else
        Rails.logger.info("21-674 Saved Claim submitted automatically to RBPS with proc_state of #{@proc_state}",
                          { saved_claim_id: @saved_claim.id, proc_id: @proc_id, automatic: true })
        StatsD.increment("#{stats_key}.automatic")
      end
    end

    def process_relationships(proc_id, veteran, payload)
      dependents = []
      # use this to make sure the created dependent and student payload line up for process_674
      # if it's nil, it is v1.
      dependent_student_map = {}
      payload&.dig('dependents_application', 'student_information').to_a.each do |student|
        dependent = DependentHigherEdAttendance.new(proc_id:, payload:, user: @user, student:).create
        dependents << dependent
        dependent_student_map[dependent[:vnp_participant_id]] = student
      end

      VnpRelationships.new(
        proc_id:,
        veteran:,
        dependents:,
        step_children: [],
        user: @user
      ).create_all

      dependents.each do |dependent|
        process_674(proc_id, dependent, payload, dependent_student_map[dependent[:vnp_participant_id]])
      end
    end

    # rubocop:disable Naming/VariableNumber
    def process_674(proc_id, dependent, payload, student = nil)
      StudentSchool.new(
        proc_id:,
        vnp_participant_id: dependent[:vnp_participant_id],
        payload:,
        user: @user,
        student:
      ).create
    end
    # rubocop:enable Naming/VariableNumber

    def vnp_proc_id(saved_claim)
      set_to_manual = saved_claim.submittable_686?
      vnp_response = bgs_service.create_proc(proc_state: set_to_manual ? 'MANUAL_VAGOV' : 'Ready')
      bgs_service.create_proc_form(
        vnp_response[:vnp_proc_id],
        '21-674'
      )

      vnp_response[:vnp_proc_id]
    end

    # the default claim type is 130SCHATTEBN (eBenefits School Attendance)
    # if we are setting the claim to be manually reviewed (we are temporarily doing this for all submissions)
    # and the Veteran is currently receiving pension benefits
    # set the claim type to 130SCAEBPMCR (PMC eBenefits School Attendance Reject)
    # else use 130SCHEBNREJ (eBenefits School Attendance Reject)
    def set_claim_type(proc_state)
      if proc_state == 'MANUAL_VAGOV'
        receiving_pension = false

        if Flipper.enabled?(:dependents_pension_check)
          pension_response = bid_service.get_awards_pension
          receiving_pension = pension_response.body['awards_pension']['is_in_receipt_of_pension']
        end

        if receiving_pension
          @end_product_name = 'PMC eBenefits School Attendance Reject'
          @end_product_code = '130SCAEBPMCR'
        else
          @end_product_name = 'eBenefits School Attendance Reject'
          @end_product_code = '130SCHEBNREJ'
        end
      end
    end

    def log_submit_failure(error)
      Rails.logger.warning('BGS::Form674.submit failed after creating benefit claim in BGS',
                           {
                             user_uuid: user.uuid,
                             saved_claim_id: saved_claim.id,
                             icn: user.icn,
                             error: error.message
                           })
    end

    def bgs_service
      BGSV2::Service.new(@user)
    end

    def bid_service
      BID::Awards::Service.new(@user)
    end

    def stats_key
      'bgs.form674'
    end
  end
end
