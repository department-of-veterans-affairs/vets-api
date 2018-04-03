# frozen_string_literal: true

class PhoneNumberSerializer < ActiveModel::Serializer
  attribute :number
  attribute :extension
  attribute :country_code
  attribute :effective_date

  def id
    nil
  end
end
