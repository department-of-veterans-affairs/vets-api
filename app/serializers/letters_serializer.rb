# frozen_string_literal: true

class LettersSerializer < ActiveModel::Serializer
  attribute :letters
  attribute :full_name

  def id
    nil
  end
end
