# frozen_string_literal: true

require 'common/models/resource'

module Mobile
  module V0
    module Appeals
      class StatusDetail < Common::Resource
        attribute :lastSocDate, Types::Date.optional
        attribute :certificationTimeliness, Types::Array.of(Integer).optional
        attribute :ssocTimeliness, Types::Array.of(Integer).optional
        attribute :decisionTimeliness, Types::Array.of(Integer).optional
        attribute :remandTimeliness, Types::Array.of(Integer).optional
        attribute :socTimeliness, Types::Array.of(Integer).optional
        attribute :remandSsocTimeliness, Types::Array.of(Integer).optional
        attribute :returnTimeliness, Types::Array.of(Integer).optional
      end
    end
  end
end
