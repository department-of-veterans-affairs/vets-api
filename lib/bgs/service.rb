# frozen_string_literal: true

require_relative 'exceptions/bgs_errors'
require 'common/client/concerns/monitoring'
require 'logging/helper/data_scrubber'
require 'logging/helper/parameter_filter'
require 'vets/shared_logging'

module BGS
  class Service
    STATSD_KEY_PREFIX = 'api.bgs'

    include BGS::Exceptions::BGSErrors
    include Vets::SharedLogging
    include Common::Client::Concerns::Monitoring
    include Logging::Helper::DataScrubber
    include Logging::Helper::ParameterFilter

    CLEARED_EPS_STATUS = 'CLR'
    CANCELED_EPS_STATUS = 'CAN'
    # Closed End Product Statuses = Cleared, Canceled
    CLOSED_EPS_STATUSES = [CLEARED_EPS_STATUS, CANCELED_EPS_STATUS].freeze

    # Journal Status Type Code
    # The alphabetic character representing the last action taken on the record
    # (I = Input, U = Update, D = Delete)
    JOURNAL_STATUS_TYPE_CODE = 'U'

    def initialize(user)
      @user = user
    end

    def create_proc(proc_state: 'Started')
      with_multiple_attempts_enabled do
        service.vnp_proc_v2.vnp_proc_create(
          log_and_return({
            vnp_proc_type_cd: 'DEPCHG',
            vnp_proc_state_type_cd: proc_state,
            creatd_dt: Time.current.iso8601,
            last_modifd_dt: Time.current.iso8601,
            submtd_dt: Time.current.iso8601
          }.merge(bgs_auth))
        )
      end
    end

    def find_rating_data
      service.rating.find_rating_data(@user.ssn)
    rescue BGS::ShareError => e
      raise Common::Exceptions::RecordNotFound, @user.user_account_uuid if e.message =~ /No record found for/

      raise e
    end

    def create_proc_form(vnp_proc_id, form_type_code)
      with_multiple_attempts_enabled do
        service.vnp_proc_form.vnp_proc_form_create(
          log_and_return({ vnp_proc_id:, form_type_cd: form_type_code }.merge(bgs_auth))
        )
      end
    end

    def update_proc(proc_id, proc_state: 'Ready')
      with_multiple_attempts_enabled do
        service.vnp_proc_v2.vnp_proc_update(
          log_and_return({
            vnp_proc_id: proc_id,
            vnp_proc_type_cd: 'DEPCHG',
            vnp_proc_state_type_cd: proc_state,
            creatd_dt: Time.current.iso8601,
            last_modifd_dt: Time.current.iso8601,
            submtd_dt: Time.current.iso8601
          }.merge(bgs_auth))
        )
      end
    end

    def create_participant(proc_id, corp_ptcpnt_id = nil)
      with_multiple_attempts_enabled do
        service.vnp_ptcpnt.vnp_ptcpnt_create(
          log_and_return({
            vnp_proc_id: proc_id,
            ptcpnt_type_nm: 'Person',
            corp_ptcpnt_id:,
            ssn: @user.ssn
          }.merge(bgs_auth))
        )
      end
    end

    def create_person(person_params)
      with_multiple_attempts_enabled do
        service.vnp_person.vnp_person_create(log_and_return(person_params.merge(bgs_auth)))
      end
    end

    def create_address(address_params)
      with_multiple_attempts_enabled do
        service.vnp_ptcpnt_addrs.vnp_ptcpnt_addrs_create(
          log_and_return(address_params.merge(bgs_auth))
        )
      end
    end

    def create_phone(proc_id, participant_id, payload)
      with_multiple_attempts_enabled do
        service.vnp_ptcpnt_phone.vnp_ptcpnt_phone_create(
          log_and_return(
            {
              vnp_proc_id: proc_id,
              vnp_ptcpnt_id: participant_id,
              phone_type_nm: 'Daytime',
              phone_nbr: payload['phone_number'],
              efctv_dt: Time.current.iso8601
            }
          .merge(bgs_auth)
          )
        )
      end
    end

    def create_child_school(child_school_params)
      with_multiple_attempts_enabled do
        service.vnp_child_school.child_school_create(log_and_return(child_school_params.merge(bgs_auth)))
      end
    end

    def create_child_student(child_student_params)
      with_multiple_attempts_enabled do
        service.vnp_child_student.child_student_create(log_and_return(child_student_params.merge(bgs_auth)))
      end
    end

    def create_relationship(relationship_params)
      with_multiple_attempts_enabled do
        service.vnp_ptcpnt_rlnshp.vnp_ptcpnt_rlnshp_create(log_and_return(relationship_params.merge(bgs_auth)))
      end
    end

    # see modules/dependents_benefits/documentation/bgs/ep_code.md
    def find_active_benefit_claim_type_increments
      claims = []
      with_multiple_attempts_enabled do
        claims = service.benefit_claims.find_claims_details_by_participant_id(participant_id: @user.participant_id)
      end
      claims[:bnft_claim_detail].filter_map do |claim|
        claim[:cp_claim_end_prdct_type_cd] if CLOSED_EPS_STATUSES.exclude?(claim[:status_type_cd])
      end.uniq
    end

    def find_benefit_claim_type_increment(claim_type_cd)
      increment_params = {
        ptcpnt_id: @user.participant_id,
        bnft_claim_type_cd: claim_type_cd,
        pgm_type_cd: 'CPL'
      }

      increment_params.merge!(user_ssn) if Settings.bgs.mock_responses == true
      log_and_return(increment_params)
      with_multiple_attempts_enabled do
        service.share_data.find_benefit_claim_type_increment(**increment_params)
      end
    end

    def vnp_create_benefit_claim(vnp_benefit_params)
      with_multiple_attempts_enabled do
        service.vnp_bnft_claim.vnp_bnft_claim_create(log_and_return(vnp_benefit_params.merge(bgs_auth)))
      end
    end

    def vnp_benefit_claim_update(vnp_benefit_params)
      with_multiple_attempts_enabled do
        service.vnp_bnft_claim.vnp_bnft_claim_update(log_and_return(vnp_benefit_params.merge(bgs_auth)))
      end
    end

    def update_manual_proc(proc_id)
      service.vnp_proc_v2.vnp_proc_update(
        log_and_return({ vnp_proc_id: proc_id, vnp_proc_state_type_cd: 'MANUAL_VAGOV',
                         vnp_proc_type_cd: 'DEPCHG' }.merge(bgs_auth))
      )
    rescue => e
      notify_of_service_exception(e, __method__)
    end

    def insert_benefit_claim(benefit_claim_params)
      service.claims.insert_benefit_claim(log_and_return(benefit_claim_params))
    end

    def bgs_auth
      auth_params = {
        jrn_dt: Time.current.iso8601,
        jrn_lctn_id: Settings.bgs.client_station_id,
        jrn_status_type_cd: 'U',
        jrn_user_id: Settings.bgs.client_username,
        jrn_obj_id: Settings.bgs.application
      }

      auth_params.merge!(user_ssn) if Settings.bgs.mock_responses == true

      auth_params
    end

    def user_ssn
      { ssn: @user.ssn }
    end

    def get_regional_office_by_zip_code(zip_code, country, province, lob, ssn)
      regional_office_response = service.routing.get_regional_office_by_zip_code(
        zip_code, country, province, lob, ssn
      )
      regional_office_response[:regional_office][:number]
    rescue => e
      notify_of_service_exception(e, __method__, 1, :warn)
      '347' # return default location id
    end

    def find_regional_offices
      service.share_data.find_regional_offices[:return]
    rescue => e
      notify_of_service_exception(e, __method__, 1, :warn)
      []
    end

    def create_note(claim_id, note_text)
      option_hash = {
        jrn_stt_tc: 'I',
        name: 'Claim rejected by VA.gov',
        bnft_clm_note_tc: 'CLMDVLNOTE',
        clm_id: claim_id,
        ptcpnt_id: @user.participant_id,
        txt: note_text
      }.merge!(bgs_auth).except!(:jrn_status_type_cd)
      # Add a log warning with the option_hash as payload
      Rails.logger.info("674 manual review #{option_hash.inspect}", option_hash)
      service.notes.create_note(option_hash)
    rescue => e
      notify_of_service_exception(e, __method__, 1, :warn)
    end

    private

    def service
      @service ||= BGS::Services.new(
        external_uid: @user.icn || @user.uuid,
        external_key: @user.common_name || @user.email
      )
    end

    def log_and_return(params)
      if Flipper.enabled?(:bgs_param_logging_enabled)
        # using Settings.vsp_environment to determine environment to filter in
        filtered_env = %w[test production].include?(Settings.vsp_environment)
        # Filter sensitive parameters in production or test environment
        logged_params = filtered_env ? scrub(filter_params(params)) : params
        Rails.logger.info('[BGS::Service] log_and_return called', { params: logged_params })
      end
      params
    rescue => e
      Rails.logger.error('[BGS::Service] log_and_return error', { error: e.message })
      params
    end
  end
end
