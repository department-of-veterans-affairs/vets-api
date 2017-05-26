# frozen_string_literal: true
class FacilitySerializer < ActiveModel::Serializer
  attributes :begin_date, :name, :code

  def id
    nil
  end
end