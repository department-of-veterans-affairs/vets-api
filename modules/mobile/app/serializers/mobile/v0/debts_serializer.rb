# frozen_string_literal: true

module Mobile
  module V0
    class DebtsSerializer
      include JSONAPI::Serializer

      set_type :debts

      attributes :fileNumber,
                 :payeeNumber,
                 :personEntitled,
                 :deductionCode,
                 :benefitType,
                 :diaryCode,
                 :diaryCodeDescription,
                 :amountOverpaid,
                 :amountWithheld,
                 :originalAR,
                 :currentAR,
                 :debtHistory

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
        Array.wrap(debts).any? { |debt| debt.payee_number != '00' }
      end

      def serialize_debt(debt, id = nil)
        Debt.new(id: id || debt['id'],
                 fileNumber: debt['fileNumber'],
                 payeeNumber: debt['payeeNumber'],
                 personEntitled: debt['personEntitled'],
                 deductionCode: debt['deductionCode'],
                 benefitType: debt['benefitType'],
                 diaryCode: debt['diaryCode'],
                 diaryCodeDescription: debt['diaryCodeDescription'],
                 amountOverpaid: debt['amountOverpaid'],
                 amountWithheld: debt['amountWithheld'],
                 originalAR: debt['originalAR'],
                 currentAR: debt['currentAR'],
                 debtHistory: debt['debtHistory'])
      end
    end
  end
end
