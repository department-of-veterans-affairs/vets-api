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
        resource = debts.map do |debt|
          DebtStruct.new(id: id || debt['id'],
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

        super(resource, { meta: { hasDependentDebts: has_dependent_debts?(debts) }})
      end

      private
      def has_dependent_debts?(debts)
        debts.any? { |debt| debt['payeeNumber'] != '00' }
      end
    end
    DebtStruct = Struct.new(:id,
                            :fileNumber,
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
                            :debtHistory)

  end
end
