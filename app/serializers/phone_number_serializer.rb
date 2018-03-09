# frozen_string_literal: true

class PhoneNumberSerializer < ActiveModel::Serializer
  attribute :number
  attribute :extension
  attribute :country_code

  def id
    nil
  end
end
