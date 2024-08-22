# frozen_string_literal: true

require 'common/models/resource'

module Mobile
  module V0
    class MilitaryInformationHistory < Common::Resource
      attribute :id, Types::String
      attribute :service_history, Types::Array
    end
  end
end
