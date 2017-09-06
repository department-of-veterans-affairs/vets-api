# frozen_string_literal: true
class LettersSerializer < ActiveModel::Serializer
  attribute :letters

  def id
    nil
  end
end
