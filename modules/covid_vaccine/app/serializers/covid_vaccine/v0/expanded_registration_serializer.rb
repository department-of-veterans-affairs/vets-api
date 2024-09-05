# frozen_string_literal: true

module CovidVaccine
  module V0
    class ExpandedRegistrationSerializer
      include JSONAPI::Serializer

      attribute :created_at

      set_id { '' }
    end
  end
end
