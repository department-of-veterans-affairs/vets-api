# frozen_string_literal: true

class ClaimStatusSerializer < ActiveModel::Serializer
  attributes :claimant_id, :claim_service_id, :claim_status, :received_date

  def id
    nil
  end
end
