# frozen_string_literal: true

class StatesSerializer < ActiveModel::Serializer
  attribute :states

  def id
    nil
  end
end
