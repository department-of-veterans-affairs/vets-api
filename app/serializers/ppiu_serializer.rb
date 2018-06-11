# frozen_string_literal: true

class PPIUSerializer < ActiveModel::Serializer
  attribute :responses

  def id
    nil
  end
end
