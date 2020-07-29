# frozen_string_literal: true

module BGSDependents
  class ChildStudent < Base
    def initialize(dependents_application, proc_participant)
      @dependents_application = dependents_application
      @proc_participant = proc_participant
    end

    def params_for_686c
      {
        saving_amt: net_worth&.dig('savings'),
        real_estate_amt: net_worth&.dig('real_estate'),
        other_asset_amt: net_worth&.dig('other_assets'),
        rmks: net_worth&.dig('remarks'),
        marage_dt: format_date(address_marrriage_tuition&.dig('marriage_date')),
        agency_paying_tuitn_nm: address_marrriage_tuition&.dig('agency_name'),
        stock_bond_amt: net_worth&.dig('securities'),
        govt_paid_tuitn_ind: convert_boolean(address_marrriage_tuition&.dig('tuition_is_paid_by_gov_agency')),
        govt_paid_tuitn_start_dt: format_date(address_marrriage_tuition&.dig('date_payments_began')),
        term_year_emplmt_income_amt: earnings_school_year&.dig('earnings_from_all_employment'),
        term_year_other_income_amt: earnings_school_year&.dig('all_other_income'),
        term_year_ssa_income_amt: earnings_school_year&.dig('annual_social_security_payments'),
        term_year_annty_income_amt: earnings_school_year&.dig('other_annuities_income'),
        next_year_annty_income_amt: earnings_next_year&.dig('other_annuities_income'),
        next_year_emplmt_income_amt: earnings_next_year&.dig('earnings_from_all_employment'),
        next_year_other_income_amt: earnings_next_year&.dig('all_other_income'),
        next_year_ssa_income_amt: earnings_next_year&.dig('annual_social_security_payments')
      }.merge(@proc_participant)
    end

    private

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

    def convert_boolean(bool)
      bool == true ? 'Y' : 'N'
    end
  end
end
