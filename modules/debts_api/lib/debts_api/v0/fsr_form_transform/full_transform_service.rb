# frozen_string_literal: true

require 'debts_api/v0/fsr_form_transform/additional_data_calculator'
require 'debts_api/v0/fsr_form_transform/asset_calculator'
require 'debts_api/v0/fsr_form_transform/expense_calculator'
require 'debts_api/v0/fsr_form_transform/income_calculator'
require 'debts_api/v0/fsr_form_transform/discretionary_income_calculator'
require 'debts_api/v0/fsr_form_transform/installment_contracts_other_debts_calculator'
require 'debts_api/v0/fsr_form_transform/personal_data_calculator'
require 'debts_api/v0/fsr_form_transform/personal_identification_calculator'
require 'debts_api/v0/fsr_form_transform/streamlined_calculator'
require 'debts_api/v0/fsr_form_transform/utils'

module DebtsApi
  module V0
    module FsrFormTransform
      class FullTransformService
        include ::FsrFormTransform::Utils

        def initialize(form)
          @assets = AssetCalculator.new(form).transform_assets
          @income = IncomeCalculator.new(form).combined_monthly_income_statement_as_json
          @expenses = ExpenseCalculator.build(form).transform_expenses
          @additional_data = AdditionalDataCalculator.new(form).get_data
          @discretionary_income = DiscretionaryIncomeCalculator.new(form).get_data
          installment_calculator = InstallmentContractsOtherDebtsCalculator.new(form)
          @installment_contracts_other_debts = installment_calculator.get_data
          @total_installments = installment_calculator.get_totals_data
          @personal_data_calculator = PersonalDataCalculator.new(form)
          @personal_data = @personal_data_calculator.get_personal_data
          @personal_identification = PersonalIdentificationCalculator.new(form).transform_personal_id
          @selected_debts_and_copays = re_camel(re_dollar_cent(form['selected_debts_and_copays'],
                                                               %w[p_h_account_number pHAccountNumber]))
          @streamlined = StreamlinedCalculator.new(form).get_streamlined_data
        end

        def transform
          {
            'income' => @income,
            'assets' => @assets,
            'expenses' => @expenses,
            'additionalData' => @additional_data,
            'discretionaryIncome' => @discretionary_income,
            'installmentContractsAndOtherDebts' => @installment_contracts_other_debts,
            'totalOfInstallmentContractsAndOtherDebts' => @total_installments,
            'personalData' => @personal_data,
            'personalIdentification' => @personal_identification,
            'applicantCertifications' => certification,
            'selectedDebtsAndCopays' => @selected_debts_and_copays,
            'streamlined' => @streamlined
          }
        end

        private

        def certification
          {
            'veteranSignature' => @personal_data_calculator.name_str,
            'veteranDateSigned' => Time.zone.today.strftime('%m/%d/%Y')
          }
        end
      end
    end
  end
end
