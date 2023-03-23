# frozen_string_literal: true

require_relative 'exceptions/bgs_errors'
require 'common/client/concerns/monitoring'

module BGS
  class Service
    STATSD_KEY_PREFIX = 'api.bgs'

    include BGS::Exceptions::BGSErrors
    include SentryLogging
    include Common::Client::Concerns::Monitoring

    # Journal Status Type Code
    # The alphabetic character representing the last action taken on the record
    # (I = Input, U = Update, D = Delete)
    JOURNAL_STATUS_TYPE_CODE = 'U'

    # It appears that a find_ch33_dd_eft that returns empty bank account information
    # will set the routing number field to '0' instead of 'nil', at least in certain cases
    EMPTY_ROUTING_NUMBER = '0'

    def initialize(user)
      @user = user
    end

    def create_proc(proc_state: 'Started')
      with_multiple_attempts_enabled do
        service.vnp_proc_v2.vnp_proc_create(
          {
            vnp_proc_type_cd: 'DEPCHG',
            vnp_proc_state_type_cd: proc_state,
            creatd_dt: Time.current.iso8601,
            last_modifd_dt: Time.current.iso8601,
            submtd_dt: Time.current.iso8601
          }.merge(bgs_auth)
        )
      end
    end

    def create_proc_form(vnp_proc_id, form_type_code)
      # Temporary log proc_id to sentry
      log_message_to_sentry(vnp_proc_id, :warn, '', { team: 'vfs-ebenefits' })
      with_multiple_attempts_enabled do
        service.vnp_proc_form.vnp_proc_form_create(
          { vnp_proc_id:, form_type_cd: form_type_code }.merge(bgs_auth)
        )
      end
    end

    def update_proc(proc_id, proc_state: 'Ready')
      with_multiple_attempts_enabled do
        service.vnp_proc_v2.vnp_proc_update(
          {
            vnp_proc_id: proc_id,
            vnp_proc_type_cd: 'DEPCHG',
            vnp_proc_state_type_cd: proc_state,
            creatd_dt: Time.current.iso8601,
            last_modifd_dt: Time.current.iso8601,
            submtd_dt: Time.current.iso8601
          }.merge(bgs_auth)
        )
      end
    end

    def create_participant(proc_id, corp_ptcpnt_id = nil)
      with_multiple_attempts_enabled do
        service.vnp_ptcpnt.vnp_ptcpnt_create(
          {
            vnp_proc_id: proc_id,
            ptcpnt_type_nm: 'Person',
            corp_ptcpnt_id:,
            ssn: @user.ssn
          }.merge(bgs_auth)
        )
      end
    end

    def create_person(person_params)
      with_multiple_attempts_enabled do
        service.vnp_person.vnp_person_create(person_params.merge(bgs_auth))
      end
    end

    def create_address(address_params)
      with_multiple_attempts_enabled do
        service.vnp_ptcpnt_addrs.vnp_ptcpnt_addrs_create(
          address_params.merge(bgs_auth)
        )
      end
    end

    def create_phone(proc_id, participant_id, payload)
      with_multiple_attempts_enabled do
        service.vnp_ptcpnt_phone.vnp_ptcpnt_phone_create(
          {
            vnp_proc_id: proc_id,
            vnp_ptcpnt_id: participant_id,
            phone_type_nm: 'Daytime',
            phone_nbr: payload['phone_number'],
            efctv_dt: Time.current.iso8601
          }.merge(bgs_auth)
        )
      end
    end

    def create_child_school(child_school_params)
      with_multiple_attempts_enabled do
        service.vnp_child_school.child_school_create(child_school_params.merge(bgs_auth))
      end
    end

    def create_child_student(child_student_params)
      with_multiple_attempts_enabled do
        service.vnp_child_student.child_student_create(child_student_params.merge(bgs_auth))
      end
    end

    def create_relationship(relationship_params)
      with_multiple_attempts_enabled do
        service.vnp_ptcpnt_rlnshp.vnp_ptcpnt_rlnshp_create(relationship_params.merge(bgs_auth))
      end
    end

    def find_benefit_claim_type_increment(claim_type_cd)
      increment_params = {
        ptcpnt_id: @user.participant_id,
        bnft_claim_type_cd: claim_type_cd,
        pgm_type_cd: 'CPL'
      }

      increment_params.merge!(user_ssn) if Settings.bgs.mock_response == true
      with_multiple_attempts_enabled do
        service.share_data.find_benefit_claim_type_increment(**increment_params)
      end
    end

    def vnp_create_benefit_claim(vnp_benefit_params)
      with_multiple_attempts_enabled do
        service.vnp_bnft_claim.vnp_bnft_claim_create(vnp_benefit_params.merge(bgs_auth))
      end
    end

    def vnp_benefit_claim_update(vnp_benefit_params)
      with_multiple_attempts_enabled do
        service.vnp_bnft_claim.vnp_bnft_claim_update(vnp_benefit_params.merge(bgs_auth))
      end
    end

    def update_manual_proc(proc_id)
      service.vnp_proc_v2.vnp_proc_update(
        { vnp_proc_id: proc_id, vnp_proc_state_type_cd: 'MANUAL_VAGOV', vnp_proc_type_cd: 'DEPCHG' }.merge(bgs_auth)
      )
    rescue => e
      notify_of_service_exception(e, __method__)
    end

    def insert_benefit_claim(benefit_claim_params)
      service.claims.insert_benefit_claim(benefit_claim_params)
    end

    def bgs_auth
      auth_params = {
        jrn_dt: Time.current.iso8601,
        jrn_lctn_id: Settings.bgs.client_station_id,
        jrn_status_type_cd: 'U',
        jrn_user_id: Settings.bgs.client_username,
        jrn_obj_id: Settings.bgs.application
      }

      auth_params.merge!(user_ssn) if Settings.bgs.mock_response == true

      auth_params
    end

    def user_ssn
      { ssn: @user.ssn }
    end

    def get_ch33_dd_eft_info
      find_ch33_dd_eft_res = find_ch33_dd_eft.body[:find_ch33_dd_eft_response][:return]
      routing_number = find_ch33_dd_eft_res[:routng_trnsit_nbr]

      find_ch33_dd_eft_res.slice(
        :dposit_acnt_nbr,
        :dposit_acnt_type_nm,
        :routng_trnsit_nbr
      ).merge(
        financial_institution_name: lambda do
          BankName.get_bank_name(@user, routing_number)
        rescue => e
          log_exception_to_sentry(e, { routing_number: }, { error: 'ch33_dd' })
          nil
        end.call
      )
    end

    def find_bank_name_by_routng_trnsit_nbr(routing_number)
      return if routing_number.blank? || routing_number == EMPTY_ROUTING_NUMBER

      with_monitoring do
        res = StatsD.measure("#{self.class::STATSD_KEY_PREFIX}.find_bank_name_by_routng_trnsit_nbr.duration") do
          service.ddeft.find_bank_name_by_routng_trnsit_nbr(routing_number)
        end
        res[:find_bank_name_by_routng_trnsit_nbr_response][:return][:bank_name]
      end
    end

    def find_ch33_dd_eft
      with_monitoring do
        StatsD.measure("#{self.class::STATSD_KEY_PREFIX}.find_ch33_dd_eft.duration") do
          service.claims.send(:request, :find_ch33_dd_eft, fileNumber: @user.ssn)
        end
      end
    end

    def update_ch33_dd_eft(routing_number, acct_number, checking_acct)
      with_monitoring do
        StatsD.measure("#{self.class::STATSD_KEY_PREFIX}.update_ch33_dd_eft.duration") do
          service.claims.send(
            :request,
            :update_ch33_dd_eft,
            ch33DdEftInput: {
              dpositAcntNbr: acct_number,
              dpositAcntTypeNm: checking_acct ? 'C' : 'S',
              fileNumber: @user.ssn,
              routngTrnsitNbr: routing_number,
              tranCode: '2'
            }
          )
        end
      end
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

      response = service.notes.create_note(option_hash)
      message = if response[:note]
                  response[:note].slice(:clm_id, :txt)
                else
                  response
                end
      log_message_to_sentry(message, :info, {}, { team: 'vfs-ebenefits' })
      response
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
  end
end
