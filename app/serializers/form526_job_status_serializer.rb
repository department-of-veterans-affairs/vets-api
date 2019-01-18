# frozen_string_literal: true

class Form526JobStatusSerializer < ActiveModel::Serializer
  attribute :claim_id
  attribute :job_id
  attribute :submission_id
  attribute :status
  attribute :ancillary_item_statuses

  def id
    nil
  end

  def claim_id
    object.submission.submitted_claim_id
  end

  def submission_id
    object.submission.id
  end

  def ancillary_item_statuses
    if object.job_class.include?('526')
      object.submission.form526_job_statuses.map do |status|
        status.attributes.except('form526_submission_id') unless status.id == object.id
      end.compact
    end
  end
end
