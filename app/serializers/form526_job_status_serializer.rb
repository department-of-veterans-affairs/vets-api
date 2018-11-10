# frozen_string_literal: true

class Form526JobStatusSerializer < ActiveModel::Serializer
  attribute :claim_id
  attribute :job_id
  attribute :status

  def id
    nil
  end

  def claim_id
    object.submission.submitted_claim_id
  end
end
