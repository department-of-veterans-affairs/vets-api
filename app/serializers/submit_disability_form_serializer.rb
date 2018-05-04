# frozen_string_literal: true

class SubmitDisabilityFormSerializer < ActiveModel::Serializer
  attribute :claim_id
  attribute :end_product_claim_code
  attribute :end_product_claim_name
  attribute :inflight_document_id

  def id
    nil
  end
end
