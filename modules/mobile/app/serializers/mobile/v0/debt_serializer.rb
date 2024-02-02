# frozen_string_literal: true

module Mobile
  module V0
    class DebtSerializer
      include JSONAPI::Serializer

      set_type :debt

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
      def initialize(debt_info)
        resource = DebtStruct.new(id: debt_info['id'],
                                  fileNumber: debt_info['fileNumber'],
                                  payeeNumber: debt_info['payeeNumber'],
                                  personEntitled: debt_info['personEntitled'],
                                  deductionCode: debt_info['deductionCode'],
                                  benefitType: debt_info['benefitType'],
                                  diaryCode: debt_info['diaryCode'],
                                  diaryCodeDescription: debt_info['diaryCodeDescription'],
                                  amountOverpaid: debt_info['amountOverpaid'],
                                  amountWithheld: debt_info['amountWithheld'],
                                  originalAR: debt_info['originalAR'],
                                  currentAR: debt_info['currentAR'],
                                  debtHistory: debt_info['debtHistory'])
        super(resource)
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
