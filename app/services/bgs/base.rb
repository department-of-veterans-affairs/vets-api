# frozen_string_literal: true

module BGS
  class Base
    def initialize(user)
      @user = user
    end

    def create_proc
      service.vnp_proc_v2.vnp_proc_create(
        {
          jrn_dt: Time.current.iso8601,
          jrn_lctn_id: Settings.bgs.client_station_id,
          jrn_status_type_cd: 'U',
          jrn_user_id: Settings.bgs.client_username,
          jrn_obj_id: Settings.bgs.application,
          vnp_proc_type_cd: 'DEPCHG', # We need this to update the proc. It has to be in either call (create, update), these are options I'm seeing: DEPCHG, COMPCLM
          ssn: @user.ssn # Just here to make the mocks work
          # vnp_proc_state_type_cd: nil, I only see 'Ready' as a value and we're doing that in the end
        }
      )
    end

    def create_proc_form(vnp_proc_id)
      service.vnp_proc_form.vnp_proc_form_create(
        {
          vnp_proc_id: vnp_proc_id,
          form_type_cd: '21-686c', # presuming this is for the 674 '21-674'
          jrn_dt: Time.current.iso8601,
          jrn_lctn_id: Settings.bgs.client_station_id,
          jrn_obj_id: Settings.bgs.application,
          jrn_status_type_cd: 'U',
          jrn_user_id: Settings.bgs.client_username,
          ssn: @user.ssn # Just here to make the mocks work
        }
      )
    end

    def update_proc(proc_id)
      service.vnp_proc_v2.vnp_proc_update(
        {
          vnp_proc_id: proc_id,
          jrn_dt: Time.current.iso8601,
          jrn_lctn_id: Settings.bgs.client_station_id,
          jrn_obj_id: Settings.bgs.application,
          jrn_status_type_cd: "U",
          jrn_user_id: Settings.bgs.client_username,
          vnp_proc_state_type_cd: "Ready",
          ssn: @user.ssn # Just here to make mocks work
        }
      )
    end

    def create_participant(proc_id, corp_ptcpnt_id = nil)
      service.vnp_ptcpnt.vnp_ptcpnt_create(
        {
          vnp_proc_id: proc_id,
          ptcpnt_type_nm: 'Person', # Hard-coded intentionally can't find any other values in all call
          jrn_dt: Time.current.iso8601,
          jrn_lctn_id: Settings.bgs.client_station_id,
          jrn_obj_id: Settings.bgs.application,
          jrn_status_type_cd: 'I', # Why is this 'I' it's 'U' other places
          jrn_user_id: Settings.bgs.client_username,
          corp_ptcpnt_id: corp_ptcpnt_id,
          ssn: @user.ssn # Just here to make mocks work
        }
      )
    end

    def create_person(proc_id, participant_id, payload)
      service.vnp_person.vnp_person_create(
        {
          vnp_proc_id: proc_id,
          vnp_ptcpnt_id: participant_id,
          jrn_dt: Time.current.iso8601,
          jrn_lctn_id: Settings.bgs.client_station_id,
          jrn_obj_id: Settings.bgs.application,
          jrn_status_type_cd: "U",
          jrn_user_id: Settings.bgs.client_username,
          first_nm: payload['first'],
          middle_nm: payload['middle'],
          last_nm: payload['last'],
          suffix_nm: payload['suffix'],
          brthdy_dt: format_date(payload['birth_date']),
          birth_state_cd: payload['place_of_birth_state'],
          birth_city_nm: payload['place_of_birth_city'],
          file_nbr: payload['va_file_number'],
          ssn_nbr: payload['ssn'],
          death_dt: format_date(payload['death_date']),
          ever_maried_ind: payload['ever_married_ind'],
          vet_ind: payload['vet_ind'],
          martl_status_type_cd: 'Married',
          # martl_status_type_cd: payload['martl_status_type_cd'],
          ssn: @user.ssn # Just here to make mocks work
        }
      )
    end

    def create_address(proc_id, participant_id, payload)
      service.vnp_ptcpnt_addrs.vnp_ptcpnt_addrs_create(
        {
          jrn_dt: Time.current.iso8601,
          jrn_lctn_id: Settings.bgs.client_station_id,
          jrn_obj_id: Settings.bgs.application,
          jrn_status_type_cd: "U",
          jrn_user_id: Settings.bgs.client_username,
          efctv_dt: Time.current.iso8601,
          vnp_ptcpnt_id: participant_id,
          vnp_proc_id: proc_id,
          ptcpnt_addrs_type_nm: 'Mailing', # What are the available types? Working on reporting deaths, could that be one?
          shared_addrs_ind: 'N',
          addrs_one_txt: payload['address_line1'],
          addrs_two_txt: payload['address_line2'],
          addrs_three_txt: payload['address_line3'],
          city_nm: payload['city'],
          cntry_nm: payload['country_name'],
          postal_cd: payload['state_code'],
          mlty_postal_type_cd: payload['military_postal_code'],
          mlty_post_office_type_cd: payload['military_post_office_type_code'],
          zip_prefix_nbr: payload['zip_code'],
          prvnc_nm: payload['state_code'],
          email_addrs_txt: payload['email_address'],
          ssn: @user.ssn # Just here to make mocks work
        }
      )
    end

    def create_phone(proc_id, participant_id, payload)
      service.vnp_ptcpnt_phone.vnp_ptcpnt_phone_create(
        {
          vnp_proc_id: proc_id,
          vnp_ptcpnt_id: participant_id,
          phone_type_nm: 'Daytime', # We should probably change this to be dynamic
          phone_nbr: payload['phone_number'],
          efctv_dt: Time.current.iso8601,
          jrn_dt: Time.current.iso8601,
          jrn_lctn_id: Settings.bgs.client_station_id,
          jrn_user_id: Settings.bgs.client_username,
          jrn_status_type_cd: "U",
          jrn_obj_id: Settings.bgs.application,
          ssn: @user.ssn # Just here to make mocks work
        }
      )
    end

    def create_relationship(proc_id, veteran_participant_id, dependent)
      service.vnp_ptcpnt_rlnshp.vnp_ptcpnt_rlnshp_create(
        {
          vnp_proc_id: proc_id,
          vnp_ptcpnt_id_a: veteran_participant_id,
          vnp_ptcpnt_id_b: dependent[:vnp_participant_id],
          ptcpnt_rlnshp_type_nm: dependent[:participant_relationship_type_name],
          jrn_dt: Time.current.iso8601,
          jrn_lctn_id: Settings.bgs.client_station_id,
          jrn_obj_id: Settings.bgs.application,
          jrn_status_type_cd: "U",
          jrn_user_id: Settings.bgs.client_username,
          family_rlnshp_type_nm: dependent[:family_relationship_type_name],
          event_dt: format_date(dependent[:event_date]),
          begin_dt: format_date(dependent[:begin_date]),
          end_dt: format_date(dependent[:end_date]),
          marage_state_cd: dependent[:marriage_state], # FE is sending us a full state name. We need code for this
          marage_city_nm: dependent[:marriage_city],
          marage_trmntn_state_cd: dependent[:divorce_state], # dependent.divorce_state this needs to be 2 digit code
          marage_trmntn_city_nm: dependent[:divorce_city],
          marage_trmntn_type_cd: dependent[:marriage_termination_type_code], # dependent.marriage_termination_type_cd, only can have "Death", "Divorce", or "Other"
          mthly_support_from_vet_amt: dependent[:living_expenses_paid_amount],
          ssn: @user.ssn # Just here to make mocks work
        }
      )
    end

    def create_child_school(proc_id, participant_id, payload)
      service.vnp_child_school.child_school_create(
        {
          vnp_proc_id: proc_id,
          jrn_dt: Time.current.iso8601,
          jrn_lctn_id: Settings.bgs.client_station_id,
          jrn_obj_id: Settings.bgs.application,
          jrn_status_type_cd: "U",
          jrn_user_id: Settings.bgs.client_username,
          vnp_ptcpnt_id: participant_id,
          gradtn_dt: format_date(payload.dig('current_term_dates', 'expected_graduation_date')),
          last_term_start_dt: format_date(payload.dig('last_term_school_information', 'term_begin')),
          last_term_end_dt: format_date(payload.dig('last_term_school_information', 'date_term_ended')),
          prev_hours_per_wk_num: payload.dig('last_term_school_information', 'hours_per_week'),
          prev_sessns_per_wk_num: payload.dig('last_term_school_information', 'classes_per_week'),
          prev_school_nm: payload.dig('last_term_school_information', 'name'),
          prev_school_cntry_nm: payload.dig('last_term_school_information', 'address', 'country_name'),
          prev_school_addrs_one_txt: payload.dig('last_term_school_information', 'address', 'address_line1'),
          prev_school_addrs_two_txt: payload.dig('last_term_school_information', 'address', 'address_line2'),
          prev_school_addrs_three_txt: payload.dig('last_term_school_information', 'address', 'address_line3'),
          prev_school_city_nm: payload.dig('last_term_school_information', 'address', 'city'),
          prev_school_postal_cd: payload.dig('last_term_school_information', 'address', 'state_code'),
          prev_school_addrs_zip_nbr: payload.dig('last_term_school_information', 'address', 'zip_code'),
          curnt_school_nm: payload.dig('school_information', 'name'),
          course_name_txt: payload.dig('program_information', 'course_of_study'),
          curnt_school_addrs_one_txt: payload.dig('school_information', 'address', 'address_line1'),
          curnt_school_addrs_two_txt: payload.dig('school_information', 'address', 'address_line2'),
          curnt_school_addrs_three_txt: payload.dig('school_information', 'address', 'address_line3'),
          curnt_school_postal_cd: payload.dig('school_information', 'address', 'state_code'),
          curnt_school_city_nm: payload.dig('school_information', 'address', 'city'),
          curnt_school_addrs_zip_nbr: payload.dig('school_information', 'address', 'zip_code'),
          curnt_school_cntry_nm: payload.dig('school_information', 'address', 'country_name'),
          curnt_sessns_per_wk_num: payload.dig('program_information', 'classes_per_week'),
          curnt_hours_per_wk_num: payload.dig('program_information', 'hours_per_week'),
          school_actual_expctd_start_dt: payload.dig('current_term_dates', 'official_school_start_date'),
          school_term_start_dt: format_date(payload.dig('current_term_dates', 'expected_student_start_date')),
          ssn: @user.ssn # Just here to make the mocks work
        }
      )
    end

    def create_child_student(proc_id, participant_id, payload)
      gov_paid_tuition = payload.dig('student_address_marriage_tuition', 'tuition_is_paid_by_gov_agency') == true ? 'Y' : 'N'
      service.vnp_child_student.child_student_create(
        {
          vnp_proc_id: proc_id,
          jrn_dt: Time.current.iso8601,
          jrn_lctn_id: Settings.bgs.client_station_id,
          jrn_obj_id: Settings.bgs.application,
          jrn_status_type_cd: "U",
          jrn_user_id: Settings.bgs.client_username,
          vnp_ptcpnt_id: participant_id,
          saving_amt: payload.dig('student_networth_information', 'savings'),
          real_estate_amt: payload.dig('student_networth_information', 'real_estate'),
          other_asset_amt: payload.dig('student_networth_information', 'other_assets'),
          rmks: payload.dig('student_networth_information', 'remarks'),
          marage_dt: format_date(payload.dig('student_address_marriage_tuition', 'marriage_date')),
          agency_paying_tuitn_nm: payload.dig('student_address_marriage_tuition', 'agency_name'),
          stock_bond_amt: payload.dig('student_networth_information', 'securities'),
          govt_paid_tuitn_ind: gov_paid_tuition,
          govt_paid_tuitn_start_dt: format_date(payload.dig('student_address_marriage_tuition', 'date_payments_began')),
          term_year_emplmt_income_amt: payload.dig('student_earnings_from_school_year', 'earnings_from_all_employment'),
          term_year_other_income_amt: payload.dig('student_earnings_from_school_year', 'all_other_income'),
          term_year_ssa_income_amt: payload.dig('student_earnings_from_school_year', 'annual_social_security_payments'),
          term_year_annty_income_amt: payload.dig('student_earnings_from_school_year', 'other_annuities_income'),
          next_year_annty_income_amt: payload.dig('student_expected_earnings_next_year', 'other_annuities_income'),
          next_year_emplmt_income_amt: payload.dig('student_expected_earnings_next_year', 'earnings_from_all_employment'),
          next_year_other_income_amt: payload.dig('student_expected_earnings_next_year', 'all_other_income'),
          next_year_ssa_income_amt: payload.dig('student_expected_earnings_next_year', 'annual_social_security_payments'),
          ssn: @user.ssn # Just here to make the mocks work
        }
      )
    end

    def create_benefit_claim(proc_id, veteran)
      service.vnp_bnft_claim.vnp_bnft_claim_create(
        {
          vnp_proc_id: proc_id,
          claim_rcvd_dt: Time.current.iso8601,
          jrn_dt: Time.current.iso8601,
          jrn_lctn_id: Settings.bgs.client_station_id,
          jrn_obj_id: Settings.bgs.application,
          jrn_status_type_cd: "U",
          jrn_user_id: Settings.bgs.client_username,
          # not sure what this is. Is this just passed in bc this will be created when we fire this call?
          status_type_cd: "CURR", # this is hard-coded in EVSS
          svc_type_cd: "CP", # this is hard-coded in EVSS
          pgm_type_cd: "COMP", # this is hard-coded in EVSS
          bnft_claim_type_cd: "130DPNEBNADJ", # This has been changed to this value in light of finding the find_benefit_claim_type_increment call 4/22
          ptcpnt_clmant_id: veteran[:vnp_participant_id],
          claim_jrsdtn_lctn_id: "335", # Not required but cannot be null all records seem to be in the 300's and the same as the below, default is 335
          intake_jrsdtn_lctn_id: "335", # Not required but cannot be null all records seem to be in the 300's, default is 335
          ptcpnt_mail_addrs_id: veteran[:vnp_participant_address_id],
          vnp_ptcpnt_vet_id: veteran[:vnp_participant_id],
          atchms_ind: "N", # this needs to be set to Y/N if documents are added/attached
          ssn: @user.ssn # Just here to make the mocks work
        }
      )
    end

    def find_benefit_claim_type_increment
      service.data.find_benefit_claim_type_increment(
        {
          ptcpnt_id: @user.participant_id,
          bnft_claim_type_cd: '130DPNEBNADJ',
          pgm_type_cd: 'CPL',
          ssn: @user.ssn # Just here to make the mocks work
        }
      )
      #  need to catch the following exception
      #  "exception": "(ns0:Server) StandardDataWebServiceBean-->findBenefitClaimTypeIncrement-->Maximum number of EPs reached for this bnftClaimTypeCd"
    end

    # 'end_product' needs to be unique; end_product_code seems to be the claimTypeCode
    # HEY we were using 796149080 as file_number and ssn to make it work. Changed it to get the mock response working
    # We get "index for PL/SQL table out of range for host" when we try to use the user's ssn in file_number
    def insert_benefit_claim(vnp_benefit_claim, veteran)
      # <endProductCode>130DPNEBNADJ</endProductCode>
      # <endProductName>endProductNameTest</endProductName>
      service.claims.insert_benefit_claim(
        {
          file_number: @user.ssn, # 796149080 This is not working with file number in the payload or the ssn value getting annot insert NULL into ("CORPPROD"."PERSON"."LAST_NM")
          ssn: @user.ssn, # this is actually needed for the service call Might want to use the payload value
          # ptcpnt_id_claimant: @user.participant_id,
          # claimant_ssn: @user.ssn,
          benefit_claim_type: "1", # this is intentionally hard coded
          payee: "00", # intentionally left hard-coded
          end_product: veteran[:benefit_claim_type_end_product], # must be unique
          # end_product_code: vnp_benefit_claim[:vnp_benefit_claim_type_code],
          end_product_code: '130DPNEBNADJ',
          first_name: veteran[:first_name], # Might want to use the payload value
          last_name: veteran[:last_name], # Might want to use the payload value
          address_line1: veteran[:address_line_one],
          address_line2: veteran[:address_line_two],
          address_line3: veteran[:address_line_three],
          city: veteran[:address_city],
          state: veteran[:address_state_code],
          postal_code: veteran[:address_zip_code],
          email_address: veteran[:email_address],
          country: veteran[:address_country], # We need the country code for this payload is sending the whole country name
          disposition: "M", # intentionally left hard-coded
          # section_unit_no: "335", # "VA office code". Tried location id's from user object, failed. Maybe we'll get it from the FE
          section_unit_no: "555",
          folder_with_claim: "N", # intentionally left hard-coded
          # end_product_name: '130 - Automated Dependency 686c', # not sure what this is
          end_product_name: 'endProductNameTest',
          pre_discharge_indicator: "N", # intentionally left hard-coded
          date_of_claim: Time.current.strftime("%m/%d/%Y")
        }
      )
    end

    def vnp_bnft_claim_update(benefit_claim_record, vnp_benefit_claim_record)
      service.vnp_bnft_claim.vnp_bnft_claim_update(
        {
          vnp_proc_id: vnp_benefit_claim_record[:vnp_proc_id],
          vnp_bnft_claim_id: vnp_benefit_claim_record[:vnp_benefit_claim_id],
          bnft_claim_type_cd: benefit_claim_record[:claim_type_code],
          claim_rcvd_dt: Time.current.iso8601,
          jrn_dt: Time.current.iso8601,
          jrn_lctn_id: Settings.bgs.client_station_id,
          jrn_obj_id: Settings.bgs.application,
          jrn_status_type_cd: "U",
          jrn_user_id: Settings.bgs.client_username,
          bnft_claim_id: benefit_claim_record[:benefit_claim_id],
          intake_jrsdtn_lctn_id: vnp_benefit_claim_record[:intake_jrsdtn_lctn_id],
          claim_jrsdtn_lctn_id: vnp_benefit_claim_record[:claim_jrsdtn_lctn_id],
          pgm_type_cd: benefit_claim_record[:program_type_code],
          ptcpnt_clmant_id: vnp_benefit_claim_record[:participant_claimant_id],
          status_type_cd: benefit_claim_record[:status_type_code],
          svc_type_cd: 'CP',
          ssn: @user.ssn # Just here to make mocks work
        }
      )
    end

    def service
      @service ||= LighthouseBGS::Services.new(
        external_uid: @user.icn,
        external_key: @user.email
      )
    end

    private

    def format_date(date)
      return nil if date.nil?

      Date.parse(date).to_time.iso8601
    end
  end
end
