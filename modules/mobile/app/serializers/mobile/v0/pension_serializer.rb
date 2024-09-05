# frozen_string_literal: true

module Mobile
  module V0
    class PensionSerializer
      include JSONAPI::Serializer

      set_id :veteran_id
      set_type :pensions
      attributes :is_eligible_for_pension,
                 :is_in_receipt_of_pension,
                 :net_worth_limit
    end
  end
end
