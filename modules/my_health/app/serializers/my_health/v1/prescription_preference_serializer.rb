# frozen_string_literal: true

module MyHealth
  module V1
    class PrescriptionPreferenceSerializer < ActiveModel::Serializer
      attributes :email_address, :rx_flag
    end
  end
end
