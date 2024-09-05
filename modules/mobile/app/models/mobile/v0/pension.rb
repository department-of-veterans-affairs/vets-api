# frozen_string_literal: true

require 'common/models/resource'

module Mobile
  module V0
    class Pension < Common::Resource
      attribute :veteran_id, Types::String
      attribute :is_eligible_for_pension, Types::Bool
      attribute :is_in_receipt_of_pension, Types::Bool
      attribute :net_worth_limit, Types::Decimal
    end
  end
end
