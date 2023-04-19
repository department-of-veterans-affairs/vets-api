# frozen_string_literal: true

require 'debt_management_center/financial_status_report_service'

module V0
  class FinancialStatusReportsController < ApplicationController
    before_action { authorize :debt, :access? }

    rescue_from ::DebtManagementCenter::FinancialStatusReportService::FSRNotFoundInRedis, with: :render_not_found

    def create
      render json: service.submit_financial_status_report(fsr_form)
    end

    def download_pdf
      send_data(
        service.get_pdf,
        type: 'application/pdf',
        filename: 'VA Form 5655 - Submitted',
        disposition: 'attachment'
      )
    end

    private

    def render_not_found
      render json: nil, status: :not_found
    end

    def full_name
      %i[first middle last]
    end

    def address
      %i[
        addressline_one
        addressline_two
        addressline_three
        city
        state_or_province
        zip_or_postal_code
        country_name
      ]
    end

    def name_amount
      %i[name amount]
    end

    # rubocop:disable Metrics/MethodLength
    def fsr_form
      params.permit(
        personal_identification: %i[fsr_reason ssn file_number],
        personal_data: [
          :telephone_number,
          :email,
          :date_of_birth,
          :married,
          { ages_of_other_dependents: [],
            veteran_full_name: full_name,
            address:,
            spouse_full_name: full_name,
            employment_history: [
              :veteran_or_spouse,
              :occupation_name,
              :from,
              :to,
              :present,
              :employer_name,
              { employer_address: address }
            ] }
        ],
        income: [
          :veteran_or_spouse,
          :monthly_gross_salary,
          :total_deductions,
          :net_take_home_pay,
          :total_monthly_net_income,
          { deductions: [
              :taxes,
              :retirement,
              :social_security,
              { other_deductions: name_amount }
            ],
            other_income: name_amount }
        ],
        expenses: [
          :rent_or_mortgage,
          :food,
          :utilities,
          :other_living_expenses,
          :expenses_installment_contracts_and_other_debts,
          :total_monthly_expenses,
          { other_living_expenses: name_amount }
        ],
        discretionary_income: %i[
          net_monthly_income_less_expenses
          amount_can_be_paid_toward_debt
        ],
        assets: [
          :cash_in_bank,
          :cash_on_hand,
          :trailers_boats_campers,
          :us_savings_bonds,
          :stocks_and_other_bonds,
          :real_estate_owned,
          :total_assets,
          { automobiles: %i[make model year resale_value],
            other_assets: name_amount }
        ],
        installment_contracts_and_other_debts: [
          :creditor_name,
          :date_started,
          :purpose,
          :original_amount,
          :unpaid_balance,
          :amount_due_monthly,
          :amount_past_due,
          { creditor_address: address }
        ],
        total_of_installment_contracts_and_other_debts: %i[
          original_amount
          unpaid_balance
          amount_due_monthly
          amount_past_due
        ],
        additional_data: [
          :additional_comments,
          { bankruptcy: %i[
            has_been_adjudicated_bankrupt
            date_discharged
            court_location
            docket_number
          ] }
        ],
        applicant_certifications: %i[
          veteran_signature
        ],
        selected_debts_and_copays: [
          :debt_type,
          :deduction_code,
          :resolution_comment,
          :resolution_option,
          { station: [:facilit_y_num] }
        ]
      ).to_hash
    end
    # rubocop:enable Metrics/MethodLength

    def service
      DebtManagementCenter::FinancialStatusReportService.new(current_user)
    end
  end
end
