# frozen_string_literal: true

class RatedDisabilitiesSerializer < ActiveModel::Serializer
  attribute :rated_disabilities

  def id
    nil
  end
end
