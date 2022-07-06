# frozen_string_literal: true

class SponsorsSerializer < ActiveModel::Serializer
  attribute :sponsors

  def id
    nil
  end
end
