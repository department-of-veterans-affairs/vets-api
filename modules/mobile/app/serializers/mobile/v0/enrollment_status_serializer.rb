# frozen_string_literal: true

module Mobile
  module V0
    class EnrollmentStatusSerializer
      include JSONAPI::Serializer

      attributes :status
    end
  end
end
