# frozen_string_literal: true

class DisabilitiesSerializer < ActiveModel::Serializer
  attribute :disabilities

  def id
    nil
  end
end
