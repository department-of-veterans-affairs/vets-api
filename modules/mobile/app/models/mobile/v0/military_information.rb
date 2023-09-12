# frozen_string_literal: true

require 'common/models/resource'

module Mobile
  module V0
    class MilitaryInformation < Common::Resource
      attribute :branch_of_service, Types::String
      attribute :begin_date, Types::String
      attribute :end_date, Types::String.optional
      attribute :formatted_begin_date, Types::String
      attribute :formatted_end_date, Types::String.optional
      attribute :character_of_discharge, Types::String
      attribute :honorable_service_indicator, Types::String
    end
  end
end
