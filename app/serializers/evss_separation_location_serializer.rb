# frozen_string_literal: true

class EVSSSeparationLocationSerializer < ActiveModel::Serializer
  attribute :separation_locations

  def id
    nil
  end
end
