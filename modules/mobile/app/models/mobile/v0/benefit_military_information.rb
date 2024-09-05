# frozen_string_literal: true

require 'common/models/resource'

module Mobile
  module V0
    class BenefitMilitaryInformation < Common::Resource
      attribute :branch, Types::String
      attribute :character_of_service, Types::String
      attribute :entered_date, Types::DateTime
      attribute :released_date, Types::DateTime
    end
  end
end
