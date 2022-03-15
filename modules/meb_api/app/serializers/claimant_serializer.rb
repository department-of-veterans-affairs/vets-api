# frozen_string_literal: true

class ClaimantSerializer < ActiveModel::Serializer
  attribute :claimant_id

  def id
    nil
  end
end
