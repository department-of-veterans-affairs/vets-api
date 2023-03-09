# frozen_string_literal: true

module Mobile
  module V0
    class ClinicsSerializer
      include JSONAPI::Serializer

      set_id :id

      set_type :clinic

      attribute :name, &:service_name
    end
  end
end
