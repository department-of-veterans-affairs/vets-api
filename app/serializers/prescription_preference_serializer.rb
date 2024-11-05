# frozen_string_literal: true

class PrescriptionPreferenceSerializer
  include JSONAPI::Serializer

  attributes :email_address, :rx_flag
end
