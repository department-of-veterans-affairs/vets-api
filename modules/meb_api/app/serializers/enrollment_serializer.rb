# frozen_string_literal: true

class EnrollmentSerializer
  include JSONAPI::Serializer

  attributes :enrollment_verifications, :last_certified_through_date, :payment_on_hold

  set_id { '' }
end
