# frozen_string_literal: true

require 'common/models/resource'

module Mobile
  module V0
    module Appeals
      class Docket < Common::Resource
        attribute :type, Types::String
        attribute :month, Types::Date
        attribute :switchDueDate, Types::Date
        attribute :eligibleToSwitch, Types::Bool
      end
    end
  end
end
