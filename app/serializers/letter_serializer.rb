# frozen_string_literal: true
class LetterSerializer < ActiveModel::Serializer
  attribute :name
  attribute :letter_type

  def id
    nil
  end
end
