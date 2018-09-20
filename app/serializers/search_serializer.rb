# frozen_string_literal: true

class SearchSerializer < ActiveModel::Serializer
  attributes :body

  def id
    nil
  end
end
