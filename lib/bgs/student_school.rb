# frozen_string_literal: true

module BGS
  class StudentSchool < Service
    def initialize(proc_id:, vnp_participant_id:, payload:, user:)
      @proc_id = proc_id
      @vnp_participant_id = vnp_participant_id
      @dependents_application = payload['dependents_application']

      super(user)
    end

    def create
      create_child_school
      create_child_student
    end

    private

    def create_child_school
      with_multiple_attempts_enabled do
        service.vnp_child_school.child_school_create(
          child_school_params
        )
      end
    end

    def create_child_student
      with_multiple_attempts_enabled do
        service.vnp_child_student.child_student_create(
          child_student_params
        )
      end
    end

    # rubocop:disable Metrics/AbcSize
    # rubocop:disable Metrics/MethodLength
    def child_school_params
      {
        last_term_start_dt: format_date(last_term_school_info&.dig('term_begin')),
        last_term_end_dt: format_date(last_term_school_info&.dig('date_term_ended')),
        prev_hours_per_wk_num: last_term_school_info&.dig('hours_per_week'),
        prev_sessns_per_wk_num: last_term_school_info&.dig('classes_per_week'),
        prev_school_nm: last_term_school_info&.dig('name'),
        prev_school_cntry_nm: last_term_school_info&.dig('address', 'country_name'),
        prev_school_addrs_one_txt: last_term_school_info&.dig('address', 'address_line1'),
        prev_school_addrs_two_txt: last_term_school_info&.dig('address', 'address_line2'),
        prev_school_addrs_three_txt: last_term_school_info&.dig('address', 'address_line3'),
        prev_school_city_nm: last_term_school_info&.dig('address', 'city'),
        prev_school_postal_cd: last_term_school_info&.dig('address', 'state_code'),
        prev_school_addrs_zip_nbr: last_term_school_info&.dig('address', 'zip_code'),
        curnt_school_nm: school_information&.dig('name'),
        curnt_school_addrs_one_txt: school_information&.dig('address', 'address_line1'),
        curnt_school_addrs_two_txt: school_information&.dig('address', 'address_line2'),
        curnt_school_addrs_three_txt: school_information&.dig('address', 'address_line3'),
        curnt_school_postal_cd: school_information&.dig('address', 'state_code'),
        curnt_school_city_nm: school_information&.dig('address', 'city'),
        curnt_school_addrs_zip_nbr: school_information&.dig('address', 'zip_code'),
        curnt_school_cntry_nm: school_information&.dig('address', 'country_name'),
        course_name_txt: program_information&.dig('course_of_study'),
        curnt_sessns_per_wk_num: program_information&.dig('classes_per_week'),
        curnt_hours_per_wk_num: program_information&.dig('hours_per_week'),
        school_actual_expctd_start_dt: current_term_dates&.dig('official_school_start_date'),
        school_term_start_dt: format_date(current_term_dates&.dig('expected_student_start_date')),
        gradtn_dt: format_date(current_term_dates&.dig('expected_graduation_date'))
      }.merge(proc_participant_auth)
    end

    def child_student_params
      {
        saving_amt: net_worth&.dig('savings'),
        real_estate_amt: net_worth&.dig('real_estate'),
        other_asset_amt: net_worth&.dig('other_assets'),
        rmks: net_worth&.dig('remarks'),
        marage_dt: format_date(address_marrriage_tuition&.dig('marriage_date')),
        agency_paying_tuitn_nm: address_marrriage_tuition&.dig('agency_name'),
        stock_bond_amt: net_worth&.dig('securities'),
        govt_paid_tuitn_ind: gov_paid_tuition,
        govt_paid_tuitn_start_dt: format_date(address_marrriage_tuition&.dig('date_payments_began')),
        term_year_emplmt_income_amt: earnings_school_year&.dig('earnings_from_all_employment'),
        term_year_other_income_amt: earnings_school_year&.dig('all_other_income'),
        term_year_ssa_income_amt: earnings_school_year&.dig('annual_social_security_payments'),
        term_year_annty_income_amt: earnings_school_year&.dig('other_annuities_income'),
        next_year_annty_income_amt: earnings_next_year&.dig('other_annuities_income'),
        next_year_emplmt_income_amt: earnings_next_year&.dig('earnings_from_all_employment'),
        next_year_other_income_amt: earnings_next_year&.dig('all_other_income'),
        next_year_ssa_income_amt: earnings_next_year&.dig('annual_social_security_payments')
      }.merge(proc_participant_auth)
    end
    # rubocop:enable Metrics/AbcSize
    # rubocop:enable Metrics/MethodLength

    def proc_participant_auth
      {
        vnp_proc_id: @proc_id,
        vnp_ptcpnt_id: @vnp_participant_id
      }.merge(bgs_auth)
    end

    # create_child_student helpers
    def address_marrriage_tuition
      @dependents_application['student_address_marriage_tuition']
    end

    def earnings_school_year
      @dependents_application['student_earnings_from_school_year']
    end

    def net_worth
      @dependents_application['student_networth_information']
    end

    def earnings_next_year
      @dependents_application['student_expected_earnings_next_year']
    end

    def gov_paid_tuition
      convert_boolean(address_marrriage_tuition&.dig('tuition_is_paid_by_gov_agency'))
    end

    # create child school helpers
    def last_term_school_info
      @dependents_application['last_term_school_information']
    end

    def school_information
      @dependents_application['school_information']
    end

    def program_information
      @dependents_application['program_information']
    end

    def current_term_dates
      @dependents_application['current_term_dates']
    end

    def convert_boolean(bool)
      bool == true ? 'Y' : 'N'
    end
  end
end
