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
                 :debt_history

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
        debt_history = Array.wrap(debt['debtHistory']).map do |history|
          {
            date: history['date'],
            letter_code: history['letterCode'],
            description: history['description']
          }
        end

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
                 debt_history:)
      end
    end
  end
end
