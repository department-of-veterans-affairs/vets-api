# frozen_string_literal: true

class EmailSerializer < ActiveModel::Serializer
  attribute :email

  def id
    nil
  end

  def email
    object.email_address['value']
  end
end
