# frozen_string_literal: true

class ExclusionPeriodSerializer < ActiveModel::Serializer
  attribute :exclusion_periods

  def id
    nil
  end
end
