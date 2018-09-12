# frozen_string_literal: true

class SearchSerializer < ActiveModel::Serializer
  attributes :results

  def id
    nil
  end
end
