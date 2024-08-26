# frozen_string_literal: true

require 'common/models/resource'

module Mobile
  module V0
    module Appeals
      class Evidence < Common::Resource
        attribute :description, Types::String
        attribute :date, Types::Date
      end
    end
  end
end
