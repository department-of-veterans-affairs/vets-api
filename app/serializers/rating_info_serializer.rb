# frozen_string_literal: true

class RatingInfoSerializer < ActiveModel::Serializer
  attributes :user_percent_of_disability, :source_system

  def id
    nil
  end

  def source_system
    'EVSS'
  end
end
