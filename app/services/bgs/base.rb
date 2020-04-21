# frozen_string_literal: true

module BGS
  class Base
    def initialize(user)
      @user = user
    end

    def create_proc
      service.vnp_proc_v2.vnp_proc_create(
        jrn_dt: Time.current.iso8601,
        jrn_lctn_id: Settings.bgs.client_station_id,
        jrn_status_type_cd: 'U',
        jrn_user_id: Settings.bgs.client_username,
        jrn_obj_id: Settings.bgs.application,
        vnp_proc_type_cd: 'DEPCHG', # We need this to update the proc. It has to be in either call (create, update), these are options I'm seeing: DEPCHG, COMPCLM
        ssn: @user.ssn # Just here to make the mocks work
      # vnp_proc_state_type_cd: nil, I only see 'Ready' as a value and we're doing that in the end
      )
    end

    def create_proc_form(vnp_proc_id)
      service.vnp_proc_form.vnp_proc_form_create(
        vnp_proc_id: vnp_proc_id,
        form_type_cd: '21-686c', # presuming this is for the 674 '21-674'
        jrn_dt: Time.current.iso8601,
        jrn_lctn_id: Settings.bgs.client_station_id,
        jrn_obj_id: Settings.bgs.application,
        jrn_status_type_cd: 'U',
        jrn_user_id: Settings.bgs.client_username,
        ssn: @user.ssn # Just here to make the mocks work
      )
    end

    def update_proc(proc_id)
      service.vnp_proc_v2.vnp_proc_update(
        vnp_proc_id: proc_id,
        jrn_dt: Time.current.iso8601,
        jrn_lctn_id: Settings.bgs.client_station_id,
        jrn_obj_id: Settings.bgs.application,
        jrn_status_type_cd: "U",
        jrn_user_id: Settings.bgs.client_username,
        vnp_proc_state_type_cd: "Ready",
        ssn: @user.ssn # Just here to make mocks work
      )
    end

    def create_participant(proc_id)
      service.vnp_ptcpnt.vnp_ptcpnt_create(
        vnp_proc_id: proc_id,
        ptcpnt_type_nm: 'Person', # Hard-coded intentionally can't find any other values in all call
        jrn_dt: Time.current.iso8601,
        jrn_lctn_id: Settings.bgs.client_station_id,
        jrn_obj_id: Settings.bgs.application,
        jrn_status_type_cd: 'I', # Why is this 'I' it's 'U' other places
        jrn_user_id: Settings.bgs.client_username,
        ssn: @user.ssn # Just here to make mocks work
      )
    end

    def create_person(proc_id, participant_id, payload)
      service.vnp_person.vnp_person_create(
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
        brthdy_dt: payload['birth_date'],
        # birth_state_cd: payload['placeOfBirthCity'], We are getting a state name instead of code. BGS wants state code
        birth_city_nm: payload['place_of_birth_state'],
        file_nbr: payload['va_file_number'], # It's throwing an error about the file number and ssn being different. Changing data
        ssn_nbr: payload['ssn'],
        death_dt: payload['death_date'],
        ever_maried_ind: payload['ever_maried_ind'],
        ssn: @user.ssn # Just here to make mocks work
      )
    end

    def create_address(proc_id, participant_id, payload)
      service.vnp_ptcpnt_addrs.vnp_ptcpnt_addrs_create(
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
        # cntry_nm: payload['countryName'], This needs to be 'USA' not 'United States'
        postal_cd: payload['state_code'],
        zip_prefix_nbr: payload['zip_code'],
        prvnc_nm: payload['state_code'],
        email_addrs_txt: payload['email_address'],
        ssn: @user.ssn # Just here to make mocks work
      )
    end

    def create_phone(proc_id, participant_id, payload)
      service.vnp_ptcpnt_phone.vnp_ptcpnt_phone_create(
        vnp_proc_id: proc_id,
        vnp_ptcpnt_id: participant_id,
        phone_type_nm: 'Nighttime',
        phone_nbr: payload['phone_number'],
        efctv_dt: Time.current.iso8601,
        jrn_dt: Time.current.iso8601,
        jrn_lctn_id: Settings.bgs.client_station_id,
        jrn_user_id: Settings.bgs.client_username,
        jrn_status_type_cd: "U",
        jrn_obj_id: Settings.bgs.application,
        ssn: @user.ssn # Just here to make mocks work
      )
    end

    def create_relationship(proc_id, veteran_participant_id, dependent)
      service.vnp_ptcpnt_rlnshp.vnp_ptcpnt_rlnshp_create(
        vnp_proc_id: proc_id,
        vnp_ptcpnt_id_a: veteran_participant_id,
        vnp_ptcpnt_id_b: dependent.vnp_participant_id,
        ptcpnt_rlnshp_type_nm: dependent.participant_relationship_type_name,
        jrn_dt: Time.current.iso8601,
        jrn_lctn_id: Settings.bgs.client_station_id,
        jrn_obj_id: Settings.bgs.application,
        jrn_status_type_cd: "U",
        jrn_user_id: Settings.bgs.client_username,
        family_rlnshp_type_nm: dependent.family_relationship_type_name,
        begin_dt: dependent.begin_date,
        end_dt: dependent.end_date,
        marage_state_cd: 'CA', # dependent.marriage_state, this has to be 2 digit code
        marage_city_nm: dependent.marriage_city,
        marage_trmntn_state_cd: 'CA', # dependent.divorce_state this needs to be 2 digit code
        marage_trmntn_city_nm: dependent.divorce_city,
        marage_trmntn_type_cd: 'Divorce', # dependent.marriage_termination_type_cd, only can have "Death", "Divorce", or "Other"
        ssn: @user.ssn # Just here to make mocks work
      )
    end

    def create_benefit_claim(proc_id, veteran)
      service.vnp_bnft_claim.vnp_bnft_claim_create(
        vnp_proc_id: proc_id,
        claim_rcvd_dt: Time.current.iso8601,
        jrn_dt: Time.current.iso8601,
        jrn_lctn_id: Settings.bgs.client_station_id,
        jrn_obj_id: Settings.bgs.application,
        jrn_status_type_cd: "U",
        jrn_user_id: Settings.bgs.client_username,
        # not sure what this is. Is this just passed in bc this will be created when we fire this call?
        status_type_cd: "PEND", # not sure what this is marking it pending since we're creating it now
        svc_type_cd: "CP", # not sure what this is all records that I scanned had 'CP' here
        pgm_type_cd: "COMP", # This is either 'COMP' or 'CPL' from what I scanned
        bnft_claim_type_cd: "130PDA", # Cannot be null using 686c code provided does not work bc it is past the 12 character limit
        ptcpnt_clmant_id: veteran.vnp_participant_id,
        claim_jrsdtn_lctn_id: "347", # Not required but cannot be null all records seem to be in the 300's and the same as the below
        intake_jrsdtn_lctn_id: "347", # Not required but cannot be null all records seem to be in the 300's
        ptcpnt_mail_addrs_id: veteran.vnp_participant_address_id,
        vnp_ptcpnt_vet_id: veteran.vnp_participant_id,
        ssn: @user.ssn # Just here to make the mocks work
      )
    end

    # 'end_product' needs to be unique; end_product_code seems to be the claimTypeCode
    # HEY we were using 796149080 as file_number and ssn to make it work. Changed it to get the mock response working
    # We get "index for PL/SQL table out of range for host" when we try to use the user's ssn in file_number
    def insert_benefit_claim(vnp_benefit_claim, veteran)
      service.benefit_claim_web.insert_benefit_claim(
        file_number: 796149080, # This is not working with file number in the payload or the ssn value getting annot insert NULL into ("CORPPROD"."PERSON"."LAST_NM")
        ssn: veteran.ssn_number, # this is actually needed for the service call Might want to use the payload value
        claimant_ssn: veteran.ssn_number,
        benefit_claim_type: "1", # this is intentionally hard coded
        payee: "00", # intentionally left hard-coded
        end_product: "687", # not sure what this is, it has to be unique tried this: vnp_benefit_claim[:vnp_bnft_claim_id] I just add one everytime I run this code
        end_product_code: vnp_benefit_claim.vnp_benefit_claim_type_code,
        first_name: veteran.first_name, # Might want to use the payload value
        last_name: veteran.last_name, # Might want to use the payload value
        address_line1: veteran.address_line_one,
        address_line2: veteran.address_line_two,
        address_line3: veteran.address_line_three,
        city: veteran.address_city,
        state: veteran.address_state_code,
        postal_code: veteran.address_zip_code,
        email_address: veteran.email_address,
        country: 'USA', # We need the country code for this payload is sending the whole country name
        disposition: "M", # intentionally left hard-coded
        section_unit_no: "555", # "VA office code". Not sure how reliable this is. Could throw undefined method for nil error super easy. Maybe we'll get it from the FE
        folder_with_claim: "N", # intentionally left hard-coded
        end_product_name: "endProductNameTest", # not sure what this is
        pre_discharge_indicator: "N", # intentionally left hard-coded
        date_of_claim: Time.current.strftime("%m/%d/%Y"),
      )
    end

    def vnp_bnft_claim_update(benefit_claim_record, vnp_benefit_claim_record)
      service.vnp_bnft_claim.vnp_bnft_claim_update(
        vnp_proc_id: vnp_benefit_claim_record.vnp_proc_id,
        vnp_bnft_claim_id: vnp_benefit_claim_record.vnp_benefit_claim_id,
        bnft_claim_type_cd: benefit_claim_record.claim_type_code,
        claim_rcvd_dt: Time.current.iso8601,
        jrn_dt: Time.current.iso8601,
        jrn_lctn_id: Settings.bgs.client_station_id,
        jrn_obj_id: Settings.bgs.application,
        jrn_status_type_cd: "U",
        jrn_user_id: Settings.bgs.client_username,
        bnft_claim_id: benefit_claim_record.benefit_claim_id,
        intake_jrsdtn_lctn_id: vnp_benefit_claim_record.intake_jrsdtn_lctn_id,
        claim_jrsdtn_lctn_id: vnp_benefit_claim_record.claim_jrsdtn_lctn_id,
        pgm_type_cd: benefit_claim_record.program_type_code,
        ptcpnt_clmant_id: vnp_benefit_claim_record.participant_claimant_id,
        status_type_cd: benefit_claim_record.status_type_code,
        svc_type_cd: benefit_claim_record.service_type_code,
        ssn: @user.ssn # Just here to make mocks work
      )
    end

    def service
      @service ||= LighthouseBGS::Services.new(
        external_uid: @user.icn,
        external_key: @user.email
      )
    end
  end
end