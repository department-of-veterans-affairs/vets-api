# frozen_string_literal: true

class PreferredNameSerializer < ActiveModel::Serializer
  attributes :preferred_name

  def id
    nil
  end
end
