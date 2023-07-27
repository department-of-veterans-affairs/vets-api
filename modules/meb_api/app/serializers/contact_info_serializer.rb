# frozen_string_literal: true

class ContactInfoSerializer < ActiveModel::Serializer
  attributes :phone
  attributes :email

  def id
    nil
  end
end
