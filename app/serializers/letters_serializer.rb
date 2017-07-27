# frozen_string_literal: true
class LettersSerializer < ActiveModel::Serializer
  attribute :letters
  attribute :address

  def id
    nil
  end
end
