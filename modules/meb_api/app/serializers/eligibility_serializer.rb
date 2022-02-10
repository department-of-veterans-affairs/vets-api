# frozen_string_literal: true

class EligibilitySerializer < ActiveModel::Serializer
  attributes :eligibility

  def id
    nil
  end
end
