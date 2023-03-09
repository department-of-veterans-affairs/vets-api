# frozen_string_literal: true

require 'fast_jsonapi'

module Mobile
  module V0
    class MilitaryInformationSerializer
      include JSONAPI::Serializer

      set_type :militaryInformation
      attribute :service_history
    end
  end
end
