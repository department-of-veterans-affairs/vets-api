# frozen_string_literal: true

class DependentsSerializer < ActiveModel::Serializer
  type :dependents

  attribute :persons

  def id
    nil
  end

  def persons
    object[:persons]
  end
end
