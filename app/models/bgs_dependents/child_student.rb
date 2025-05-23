# frozen_string_literal: true

module BGSDependents
  class ChildStudent < Base
    attribute :student_address_marriage_tuition, Hash
    attribute :student_earnings_from_school_year, Hash
    attribute :student_networth_information, Hash
    attribute :student_expected_earnings_next_year, Hash
    attribute :student_information, Hash

    def initialize(dependents_application, proc_id, vnp_participant_id, student = nil, is_v2: false)
      @proc_id = proc_id
      @vnp_participant_id = vnp_participant_id
      @dependents_application = dependents_application
      @is_v2 = is_v2
      @student = student

      assign_attributes(@is_v2 ? student : dependents_application)
    end

    # rubocop:disable Metrics/MethodLength
    def params_for_686c
      {
        vnp_proc_id: @proc_id,
        vnp_ptcpnt_id: @vnp_participant_id,
        saving_amt: student_networth_information&.dig('savings'),
        real_estate_amt: student_networth_information&.dig('real_estate'),
        other_asset_amt: student_networth_information&.dig('other_assets'),
        rmks: @is_v2 ? student_information&.dig('remarks') : student_networth_information&.dig('remarks'),
        marage_dt: format_date(@is_v2 ? student_information&.dig('marriage_date') : student_address_marriage_tuition&.dig('marriage_date')), # rubocop:disable Layout/LineLength
        agency_paying_tuitn_nm: student_address_marriage_tuition&.dig('agency_name'),
        stock_bond_amt: student_networth_information&.dig('securities'),
        govt_paid_tuitn_ind: convert_boolean(@is_v2 ? student_information&.dig('tuition_is_paid_by_gov_agency') : student_address_marriage_tuition&.dig('tuition_is_paid_by_gov_agency')), # rubocop:disable Layout/LineLength
        govt_paid_tuitn_start_dt: format_date(student_address_marriage_tuition&.dig('date_payments_began')),
        term_year_emplmt_income_amt: student_earnings_from_school_year&.dig('earnings_from_all_employment'),
        term_year_other_income_amt: student_earnings_from_school_year&.dig('all_other_income'),
        term_year_ssa_income_amt: student_earnings_from_school_year&.dig('annual_social_security_payments'),
        term_year_annty_income_amt: student_earnings_from_school_year&.dig('other_annuities_income'),
        next_year_annty_income_amt: student_expected_earnings_next_year&.dig('other_annuities_income'),
        next_year_emplmt_income_amt: student_expected_earnings_next_year&.dig('earnings_from_all_employment'),
        next_year_other_income_amt: student_expected_earnings_next_year&.dig('all_other_income'),
        next_year_ssa_income_amt: student_expected_earnings_next_year&.dig('annual_social_security_payments'),
        acrdtdSchoolInd: convert_boolean(@dependents_application&.dig('current_term_dates', 'is_school_accredited')),
        atndedSchoolCntnusInd: convert_boolean(@dependents_application&.dig('program_information', 'student_is_enrolled_full_time')), # rubocop:disable Layout/LineLength
        stopedAtndngSchoolDt: format_date(@dependents_application&.dig('child_stopped_attending_school', 'date_stopped_attending')) # rubocop:disable Layout/LineLength
      }
    end
    # rubocop:enable Metrics/MethodLength

    # rubocop:disable Metrics/MethodLength
    def params_for_686c_v2
      {
        vnp_proc_id: @proc_id,
        vnp_ptcpnt_id: @vnp_participant_id,
        saving_amt: student_networth_information&.dig('savings'),
        real_estate_amt: student_networth_information&.dig('real_estate'),
        other_asset_amt: student_networth_information&.dig('other_assets'),
        rmks: @student&.dig('remarks'),
        marage_dt: format_date(@student&.dig('marriage_date')),
        agency_paying_tuitn_nm: nil,
        stock_bond_amt: student_networth_information&.dig('securities'),
        govt_paid_tuitn_ind: convert_boolean(@student&.dig('tuition_is_paid_by_gov_agency')),
        govt_paid_tuitn_start_dt: format_date(@student&.dig('benefit_payment_date')),
        term_year_emplmt_income_amt: student_earnings_from_school_year&.dig('earnings_from_all_employment'),
        term_year_other_income_amt: student_earnings_from_school_year&.dig('all_other_income'),
        term_year_ssa_income_amt: student_earnings_from_school_year&.dig('annual_social_security_payments'),
        term_year_annty_income_amt: student_earnings_from_school_year&.dig('other_annuities_income'),
        next_year_annty_income_amt: student_expected_earnings_next_year&.dig('other_annuities_income'),
        next_year_emplmt_income_amt: student_expected_earnings_next_year&.dig('earnings_from_all_employment'),
        next_year_other_income_amt: student_expected_earnings_next_year&.dig('all_other_income'),
        next_year_ssa_income_amt: student_expected_earnings_next_year&.dig('annual_social_security_payments'),
        acrdtdSchoolInd: convert_boolean(@student&.dig('school_information', 'is_school_accredited')),
        atndedSchoolCntnusInd: convert_boolean(@student&.dig('school_information', 'student_is_enrolled_full_time')),
        stopedAtndngSchoolDt: nil
      }
    end
    # rubocop:enable Metrics/MethodLength

    private

    def convert_boolean(bool)
      bool == true ? 'Y' : 'N'
    end

    def assign_attributes(data)
      @student_address_marriage_tuition = data['student_address_marriage_tuition']
      @student_earnings_from_school_year = data['student_earnings_from_school_year']
      @student_networth_information = data['student_networth_information']
      @student_expected_earnings_next_year = data['student_expected_earnings_next_year']
      @student_information = data['student_information']
    end
  end
end
