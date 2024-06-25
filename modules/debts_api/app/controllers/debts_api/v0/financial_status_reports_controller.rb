# frozen_string_literal: true

require 'debts_api/v0/financial_status_report_service'
require 'debts_api/v0/fsr_rehydration_service'
require 'debts_api/v0/fsr_form_transform/full_transform_service'

module DebtsApi
  module V0
    class FinancialStatusReportsController < ApplicationController
      service_tag 'financial-report'
      before_action { authorize :debt, :access? }

      rescue_from DebtsApi::V0::FinancialStatusReportService::FSRNotFoundInRedis, with: :render_not_found

      def create
        render json: service.submit_financial_status_report(fsr_form)
      end

      def transform_and_submit
        output = full_transform_service.transform
        render json: service.submit_financial_status_report(output.to_h)
      end

      def download_pdf
        send_data(
          service.get_pdf,
          type: 'application/pdf',
          filename: 'VA Form 5655 - Submitted',
          disposition: 'attachment'
        )
      end

      def submissions
        submissions = DebtsApi::V0::Form5655Submission.where(user_uuid: current_user.uuid)
        render json: { 'submissions' => submissions.map { |sub| { 'id' => sub.id } } }
      end

      def rehydrate
        submission_id = params[:submission_id]

        DebtsApi::V0::FsrRehydrationService.attempt_rehydration(user_uuid: current_user.uuid, submission_id:)

        render json: { result: 'FSR rehydrated' }
      rescue ActiveRecord::RecordNotFound
        render json: { error: "Form5655Submission record #{submission_id} not found." }, status: :not_found
      rescue DebtsApi::V0::FsrRehydrationService::UserDoesNotOwnsubmission
        render json: { error: "User #{current_user.uuid} does not own submission #{submission_id}" },
               status: :unauthorized
      rescue DebtsApi::V0::FsrRehydrationService::NoInProgressFormDataStored
        render json: { error: "Form5655Submission record #{submission_id} missing InProgressForm data",
                       status: :not_found }
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
          streamlined: %i[
            value
            type
          ],
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
            :current_ar,
            :debt_type,
            :deduction_code,
            :p_h_amt_due,
            :p_h_dfn_number,
            :p_h_cerner_patient_id,
            :resolution_comment,
            :resolution_option,
            { station: [:facilit_y_num] }
          ]
        ).to_hash
      end
      # rubocop:enable Metrics/MethodLength

      # rubocop:disable Metrics/MethodLength
      def full_transform_form
        params.permit(
          :'view:enhanced_financial_status_report',
          :'view:streamlined_waiver',
          :'view:streamlined_waiver_asset_update',
          :'view:review_page_navigation_toggle',
          questions: %i[
            has_repayments has_credit_card_bills has_recreational_vehicle
            has_vehicle has_real_estate spouse_has_benefits is_married
            has_dependents has_been_adjudicated_bankrupt vet_is_employed
            spouse_is_employed
          ],
          'view:components': {
            'view:contracts_additional_info': {}, 'view:rec_vehicle_info': {},
            'view:real_estate_additional_info': {}, 'view:marital_status': {},
            'view:veteran_info': {}, 'view:dependents_additional_info': {},
            'view:va_benefits_on_file': {}
          },
          assets: [
            :rec_vehicle_amount, :real_estate_value,
            {
              monetary_assets: %i[name amount],
              other_assets: %i[name amount],
              automobiles: %i[make model resale_value]
            }
          ],
          benefits: { spouse_benefits: %i[compensation_and_pension education] },
          personal_data: [
            :date_of_birth, :telephone_number, :email_address,
            {
              spouse_full_name: %i[first last],
              veteran_full_name: %i[first last middle],
              veteran_contact_information: [
                :email,
                {
                  mobile_phone: %i[
                    area_code country_code created_at extension
                    effective_end_date effective_start_date id
                    is_international is_textable is_text_permitted
                    is_tty is_voicemailable phone_number phone_type
                    source_date source_system_user transaction_id
                    updated_at vet360_id
                  ],
                  address: %i[
                    address_line1 address_line2 address_pou address_type
                    city country_name country_code_iso2 country_code_iso3
                    country_code_fips county_code county_name created_at
                    effective_end_date effective_start_date id province
                    source_date source_system_user state_code transaction_id
                    updated_at validation_key vet360_id zip_code zip_code_suffix
                  ]
                }
              ],
              dependents: [:dependent_age],
              address: %i[
                street city state country postal_code
              ],
              employment_history: [
                veteran: [
                  employment_records: [
                    :type, :from, :to, :is_current, :employer_name, :gross_monthly_income,
                    { deductions: %i[name amount] }
                  ]
                ],
                spouse: [
                  sp_employment_records: [
                    :type, :from, :to, :is_current, :employer_name, :gross_monthly_income,
                    { deductions: %i[name amount] }
                  ]
                ]
              ]
            }
          ],
          personal_identification: %i[ssn file_number],
          selected_debts_and_copays: [
            :resolution_waiver_check, :resolution_option, :file_number,
            :payee_number, :person_entitled, :deduction_code, :benefit_type,
            :diary_code, :diary_code_description, :amount_overpaid, :amount_withheld,
            :original_ar, :current_ar,
            :id, :debt_type, :resolution_comment,
            { debt_history: %i[date letter_code description] }
          ],
          additional_income: [
            addl_inc_records: %i[name amount],
            spouse: [
              sp_addl_income: %i[name amount]
            ]
          ],
          expenses: [
            expense_records: %i[name amount],
            credit_card_bills: %i[
              purpose creditor_name original_amount unpaid_balance
              amount_due_monthly date_started amount_past_due
            ]
          ],
          utility_records: %i[name amount],
          other_expenses: %i[name amount],
          additional_data: [
            :additional_comments,
            { bankruptcy: %i[date_discharged court_location docket_number] }
          ],
          income: [:veteran_or_spouse],
          gmt_data: [
            :is_eligible_for_streamlined, :gmt_threshold, { error: [:error] }
          ],
          installment_contracts: %i[
            purpose creditor_name original_amount unpaid_balance
            amount_due_monthly date_started amount_past_due
          ]
        ).to_h
      end
      # rubocop:enable Metrics/MethodLength

      def service
        DebtsApi::V0::FinancialStatusReportService.new(current_user)
      end

      def full_transform_service
        DebtsApi::V0::FsrFormTransform::FullTransformService.new(full_transform_form)
      end
    end
  end
end
