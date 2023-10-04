# frozen_string_literal: true

module Mobile
  module V0
    class ObservationSerializer
      include JSONAPI::Serializer

      set_type :observation

      attributes :status,
                 :category,
                 :code,
                 :subject,
                 :effectiveDateTime,
                 :issued,
                 :performer,
                 :valueQuantity
    end
  end
end
