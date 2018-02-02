# frozen_string_literal: true

class TreatmentCentersSerializer < ActiveModel::Serializer
  attribute :treatment_centers

  def id
    nil
  end
end
