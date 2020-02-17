# frozen_string_literal: true

class DependentsSerializer < ActiveModel::Serializer
  attribute :dependents

  def id
    nil
  end
end
