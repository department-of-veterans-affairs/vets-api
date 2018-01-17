# frozen_string_literal: true

class PrescriptionPreferenceSerializer < ActiveModel::Serializer
  attributes :email_address, :rx_flag
end
