# frozen_string_literal: true

class ZipcodesSerializer < ActiveModel::Serializer
  attribute :zipcodes

  def id
    nil
  end
end
