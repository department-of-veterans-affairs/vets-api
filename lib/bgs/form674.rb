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

module BGS
  class Form674
    include SentryLogging

    def initialize(user)
      @user = user
      @end_product_name = '130 - Automated School Attendance 674'
      @end_product_code = '130SCHATTEBN'
    end

    # rubocop:disable Metrics/MethodLength
    def submit(payload)
      proc_id = create_proc_id_and_form
      veteran = VnpVeteran.new(proc_id:, payload:, user: @user, claim_type: '130SCHATTEBN').create

      process_relationships(proc_id, veteran, payload)

      vnp_benefit_claim = VnpBenefitClaim.new(proc_id:, veteran:, user: @user)
      vnp_benefit_claim_record = vnp_benefit_claim.create

      set_claim_type('MANUAL_VAGOV') # we are TEMPORARILY always setting to MANUAL_VAGOV for 674

      # temporary logging to troubleshoot
      log_message_to_sentry("#{proc_id} - #{@end_product_code}", :warn, '', { team: 'vfs-ebenefits' })

      benefit_claim_record = BenefitClaim.new(
        args: {
          vnp_benefit_claim: vnp_benefit_claim_record,
          veteran:,
          user: @user,
          proc_id:,
          end_product_name: @end_product_name,
          end_product_code: @end_product_code
        }
      ).create

      vnp_benefit_claim.update(benefit_claim_record, vnp_benefit_claim_record)

      # we only want to add a note if the claim is being set to MANUAL_VAGOV
      # but for now we are temporarily always setting to MANUAL_VAGOV for 674
      # when that changes, we need to surround this block of code in an IF statement
      note_text = 'Claim set to manual by VA.gov: This application needs manual review because a 674 was submitted.'
      bgs_service.create_note(benefit_claim_record[:benefit_claim_id], note_text)

      bgs_service.update_proc(proc_id, proc_state: 'MANUAL_VAGOV')
    end
    # rubocop:enable Metrics/MethodLength

    private

    def process_relationships(proc_id, veteran, payload)
      dependent = DependentHigherEdAttendance.new(proc_id:, payload:, user: @user).create

      VnpRelationships.new(
        proc_id:,
        veteran:,
        dependents: [dependent],
        step_children: [],
        user: @user
      ).create_all

      process_674(proc_id, dependent, payload)
    end

    def process_674(proc_id, dependent, payload)
      StudentSchool.new(
        proc_id:,
        vnp_participant_id: dependent[:vnp_participant_id],
        payload:,
        user: @user
      ).create
    end

    def create_proc_id_and_form
      vnp_response = bgs_service.create_proc(proc_state: 'MANUAL_VAGOV')
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

    def bgs_service
      BGS::Service.new(@user)
    end

    def bid_service
      BID::Awards::Service.new(@user)
    end
  end
end
