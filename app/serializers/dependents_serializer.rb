# frozen_string_literal: true

class DependentsSerializer < ActiveModel::Serializer
  attribute :persons

  def id
    nil
  end

  def persons
    object[:persons]
  end
end
