# frozen_string_literal: true

module Mobile
  module V0
    class DebtSerializer
      include JSONAPI::Serializer

      set_type :debts

      attributes :has_dependent_debts,
                 :debts
      def initialize(user_id, debt_info)
        resource = DebtsStruct.new(id: user_id,
                                   has_dependent_debts: debt_info[:has_dependent_debts],
                                   debts: debt_info[:debts])
        super(resource)
      end
    end
    DebtsStruct = Struct.new(:id, :has_dependent_debts, :debts)
  end
end
