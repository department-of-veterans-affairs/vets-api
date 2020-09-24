# frozen_string_literal: true

class FullNameSerializer < ActiveModel::Serializer
  attribute :first
  attribute :middle
  attribute :last
  attribute :suffix

  def id
    nil
  end

  def first
    object[:first]
  end

  def middle
    object[:middle]
  end

  def last
    object[:last]
  end

  def suffix
    object[:suffix]
  end
end
