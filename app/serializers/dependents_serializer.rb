# frozen_string_literal: true

class DependentsSerializer < ActiveModel::Serializer
  type :dependents

  attribute :persons

  def id
    nil
  end

  def persons
    return [object[:persons]] if object[:persons].instance_of?(Hash)

    object[:persons]
  end
end
