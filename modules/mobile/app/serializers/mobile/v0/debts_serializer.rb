# frozen_string_literal: true

module Mobile
  module V0
    class DebtsSerializer
      include JSONAPI::Serializer

      set_type :debts

      attributes :file_number,
                 :payee_number,
                 :person_entitled,
                 :deduction_code,
                 :benefit_type,
                 :diary_code,
                 :diary_code_description,
                 :amount_overpaid,
                 :amount_withheld,
                 :original_ar,
                 :current_ar,
                 :debt_history,
                 :fiscal_transaction_data

      def initialize(debts, id = nil)
        resource = if debts.is_a? Array
                     debts.map { |debt| serialize_debt(debt, id) }
                   else
                     serialize_debt(debts)
                   end

        super(resource, { meta: { hasDependentDebts: dependent_debts?(debts) } })
      end

      private

      def dependent_debts?(debts)
        Array.wrap(debts).any? { |debt| debt['payeeNumber'] != '00' }
      end

      def serialize_debt(debt, id = nil)
        debt_history = serialize_debt_history(debt)

        fiscal_transaction_data = serialize_fiscal_transaction_data(debt)

        Debt.new(id: id || debt['id'],
                 file_number: debt['fileNumber'],
                 payee_number: debt['payeeNumber'],
                 person_entitled: debt['personEntitled'],
                 deduction_code: debt['deductionCode'],
                 benefit_type: debt['benefitType'],
                 diary_code: debt['diaryCode'],
                 diary_code_description: debt['diaryCodeDescription'],
                 amount_overpaid: debt['amountOverpaid'],
                 amount_withheld: debt['amountWithheld'],
                 original_ar: debt['originalAR'],
                 current_ar: debt['currentAR'],
                 debt_history:,
                 fiscal_transaction_data:)
      end

      def serialize_debt_history(debt)
        Array.wrap(debt['debtHistory']).map do |history|
          {
            date: history['date'],
            letter_code: history['letterCode'],
            description: history['description']
          }
        end
      end

      def serialize_fiscal_transaction_data(debt) # rubocop:disable Metrics/MethodLength
        Array.wrap(debt['fiscalTransactionData']).map do |data|
          {
            debt_id: data['debtId'],
            debt_increase_amount: data['debtIncreaseAmount'],
            hines_code: data['hinesCode'],
            offset_amount: data['offsetAmount'],
            offset_type: data['offsetType'],
            payment_type: data['paymentType'],
            transaction_admin_amount: data['transactionAdminAmount'],
            transaction_court_amount: data['transactionCourtAmount'],
            transaction_date: data['transactionDate'],
            transaction_description: data['transactionDescription'],
            transaction_explanation: data['transactionExplanation'],
            transaction_fiscal_code: data['transactionFiscalCode'],
            transaction_fiscal_source: data['transactionFiscalSource'],
            transaction_fiscal_year: data['transactionFiscalYear'],
            transaction_interest_amount: data['transactionInterestAmount'],
            transaction_marshall_amount: data['transactionMarshallAmount'],
            transaction_principal_amount: data['transactionPrincipalAmount'],
            transaction_total_amount: data['transactionTotalAmount']
          }
        end
      end
    end
  end
end
