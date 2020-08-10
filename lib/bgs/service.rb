# frozen_string_literal: true

module BGS
  class Service
    include BGS::Exceptions::BGSErrors
    # Journal Status Type Code
    # The alphabetic character representing the last action taken on the record
    # (I = Input, U = Update, D = Delete)
    JOURNAL_STATUS_TYPE_CODE = 'U'

    def initialize(user)
      @user = user
    end

    def create_proc
      with_multiple_attempts_enabled do
        service.vnp_proc_v2.vnp_proc_create(
          { vnp_proc_type_cd: 'DEPCHG', vnp_proc_state_type_cd: 'Started' }.merge(bgs_auth)
        )
      end
    end

    def create_proc_form(vnp_proc_id)
      with_multiple_attempts_enabled do
        service.vnp_proc_form.vnp_proc_form_create(
          { vnp_proc_id: vnp_proc_id, form_type_cd: '21-686c' }.merge(bgs_auth)
        )
      end
    end

    def update_proc(proc_id)
      with_multiple_attempts_enabled do
        service.vnp_proc_v2.vnp_proc_update(
          {
            vnp_proc_id: proc_id,
            vnp_proc_state_type_cd: 'Ready'
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
            corp_ptcpnt_id: corp_ptcpnt_id,
            ssn: @user[:ssn]
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

    def find_benefit_claim_type_increment
      increment_params = {
        ptcpnt_id: @user[:participant_id],
        bnft_claim_type_cd: '130DPNEBNADJ',
        pgm_type_cd: 'CPL'
      }

      increment_params.merge!(user_ssn) if Settings.bgs.mock_response == true

      with_multiple_attempts_enabled do
        service.data.find_benefit_claim_type_increment(increment_params)
      end
    end

    def vnp_create_benefit_claim(vnp_benefit_params)
      service.vnp_bnft_claim.vnp_bnft_claim_create(vnp_benefit_params.merge(bgs_auth))
    end

    def vnp_benefit_claim_update(vnp_benefit_params)
      service.vnp_bnft_claim.vnp_bnft_claim_update(vnp_benefit_params.merge(bgs_auth))
    end

    def update_manual_proc(proc_id)
      service.vnp_proc_v2.vnp_proc_update(
        { vnp_proc_id: proc_id, vnp_proc_state_type_cd: 'Manual' }.merge(bgs_auth)
      )
    rescue => e
      notify_of_service_exception(e, __method__)
    end

    def get_va_file_number
      person = service.people.find_person_by_ptcpnt_id(@user[:participant_id])

      person[:file_nbr]
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
      { ssn: @user[:ssn] }
    end

    private

    def service
      @service ||= BGS::Services.new(external_uid: @user[:icn], external_key: @user[:external_key])
    end
  end
end
