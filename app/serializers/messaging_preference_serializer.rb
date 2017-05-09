# frozen_string_literal: true
class MessagingPreferenceSerializer < ActiveModel::Serializer
  attributes :email_address, :frequency

  def id
    nil
  end
end
