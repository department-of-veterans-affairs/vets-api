# frozen_string_literal: true
class DisabilityRatingSerializer < ActiveModel::Serializer
  attributes :ratings, :service_connected_combined_degree

  # activemodel serializer requires an id attr for json-api spec
  def id
    0
  end
end
