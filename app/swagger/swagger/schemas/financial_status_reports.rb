# frozen_string_literal: true

module Swagger
  module Schemas
    class FinancialStatusReports
      include Swagger::Blocks

      swagger_schema :FullName, type: :object do
        property :first, type: :string
        property :middle, type: :string
        property :last, type: :string
      end

      swagger_schema :Address, type: :object do
        property :address_line_one, type: :string
        property :address_line_two, type: :string
        property :address_line_three, type: :string
        property :city, type: :string
        property :state_or_province, type: :string
        property :zip_or_postal_code, type: :string
        property :country_name, type: :string
      end

      swagger_schema :PersonalIdentification do
        key :required, %i[ssn file_number fsr_reason]
        property :ssn, type: :string
        property :file_number, type: :string
        property :fsr_reason, type: :string
      end

      swagger_schema :PersonalData do
        property :veteran_full_name, type: :object do
          key :$ref, :FullName
        end

        property :address, type: :object do
          key :$ref, :Address
        end

        property :telephone_number, type: :string
        property :email_address, type: :string
        property :date_of_birth, type: :string
        property :married, type: :boolean

        property :spouse_full_name, type: :object do
          key :$ref, :FullName
        end

        property :ages_of_other_dependents, type: :array do
          items do
            key :type, :string
          end
        end

        property :employment_history, type: :array do
          items do
            property :veteran_or_spouse, type: :string
            property :occupation_name, type: :string
            property :from, type: :string
            property :to, type: :string
            property :present, type: :boolean
            property :employer_name, type: :string
            property :employer_address, type: :object do
              key :$ref, :Address
            end
          end
        end
      end

      swagger_schema :Income do
        property :veteran_or_spouse, type: :string
        property :monthly_gross_salary, type: :string
        property :deductions, type: :object do
          property :taxes, type: :string
          property :retirement, type: :string
          property :social_security, type: :string
          property :other_deductions, type: :object do
            property :name, type: :string
            property :amount, type: :string
          end
        end
        property :total_deductions, type: :string
        property :net_take_home_pay, type: :string
        property :other_income, type: :object do
          property :name, type: :string
          property :amount, type: :string
        end
        property :total_monthly_net_income, type: :string
      end

      swagger_schema :Expenses do
        property :rent_or_mortgage, type: :string
        property :food, type: :string
        property :utilities, type: :string
        property :other_living_expenses, type: :object do
          property :name, type: :string
          property :amount, type: :string
        end
        property :expenses_installment_contracts_and_other_debts, type: :string
        property :total_monthly_expenses, type: :string
      end

      swagger_schema :DiscretionaryIncome do
        property :net_monthly_income_less_expenses, type: :string
        property :amount_can_be_paid_toward_debt, type: :string
      end

      swagger_schema :Assets do
        property :cash_in_bank, type: :string
        property :cash_on_hand, type: :string
        property :automobiles, type: :array do
          items do
            property :make, type: :string
            property :model, type: :string
            property :year, type: :string
            property :resale_value, type: :string
          end
        end
        property :trailers_boats_campers, type: :string
        property :us_savings_bonds, type: :string
        property :stocks_and_other_bonds, type: :string
        property :real_estate_owned, type: :string
        property :other_assets, type: :array do
          items do
            property :name, type: :string
            property :amount, type: :string
          end
        end
        property :total_assets, type: :string
      end

      swagger_schema :InstallmentContractsAndOtherDebts do
        property :creditor_name, type: :string
        property :creditor_address, type: :object do
          key :$ref, :Address
        end
        property :date_started, type: :string
        property :purpose, type: :string
        property :original_amount, type: :string
        property :unpaid_balance, type: :string
        property :amount_due_monthly, type: :string
        property :amount_past_due, type: :string
      end

      swagger_schema :TotalOfInstallmentContractsAndOtherDebts do
        property :original_amount, type: :string
        property :unpaid_balance, type: :string
        property :amount_due_monthly, type: :string
        property :amount_past_due, type: :string
      end

      swagger_schema :AdditionalData do
        property :bankruptcy, type: :object do
          property :has_been_adjudicated_bankrupt, type: :boolean
          property :date_discharged, type: :string
          property :court_location, type: :string
          property :docket_number, type: :string
        end
        property :additional_comments, type: :string
      end

      swagger_schema :FinancialStatusReport do
        key :required, [:personal_identification]

        property :personal_identification, type: :object do
          key :$ref, :PersonalIdentification
        end

        property :personal_data, type: :object do
          key :$ref, :PersonalData
        end

        property :income, type: :array do
          items do
            key :$ref, :Income
          end
        end

        property :expenses, type: :object do
          key :$ref, :Expenses
        end

        property :discretionary_income, type: :object do
          key :$ref, :DiscretionaryIncome
        end

        property :assets, type: :object do
          key :$ref, :Assets
        end

        property :installment_contracts_and_other_debts, type: :array do
          items do
            key :$ref, :InstallmentContractsAndOtherDebts
          end
        end

        property :total_of_installment_contracts_and_other_debts, type: :object do
          key :$ref, :TotalOfInstallmentContractsAndOtherDebts
        end

        property :additional_data do
          key :$ref, :AdditionalData
        end

        property :selected_debts_and_copays, type: :array do
          items do
            property :debt_type, type: :string
            property :deduction_code, type: :string
            property :resolution_comment, type: :string
            property :resolution_option, type: :string
            property :station, type: :object do
              property :facilit_y_num, type: :string
            end
          end
        end
      end
    end
  end
end
