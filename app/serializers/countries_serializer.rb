# frozen_string_literal: true

class CountriesSerializer < ActiveModel::Serializer
  attribute :countries

  def id
    nil
  end
end
