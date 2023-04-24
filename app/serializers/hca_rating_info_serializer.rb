# frozen_string_literal: true

class HCARatingInfoSerializer < ActiveModel::Serializer
  attribute :user_percent_of_disability

  def user_percent_of_disability
    object[:user_percent_of_disability].to_i
  end

  def id
    nil
  end
end
