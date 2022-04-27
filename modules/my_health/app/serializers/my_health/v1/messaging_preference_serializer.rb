# frozen_string_literal: true

module MyHealth
  module V1
    class MessagingPreferenceSerializer < ActiveModel::Serializer
      attributes :email_address, :frequency
    end
  end
end
