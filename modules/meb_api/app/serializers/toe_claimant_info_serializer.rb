# frozen_string_literal: true

class ToeClaimantInfoSerializer < ActiveModel::Serializer
  attribute :claimant
  attribute :service_data
  attribute :toe_sponsors

  def id
    nil
  end
end
