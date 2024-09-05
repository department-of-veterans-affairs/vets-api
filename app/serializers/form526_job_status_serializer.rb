# frozen_string_literal: true

class Form526JobStatusSerializer
  include JSONAPI::Serializer

  set_id { '' }
  set_type :form526_job_statuses

  attribute :claim_id do |object|
    object.submission.submitted_claim_id
  end

  attributes :job_id

  attribute :submission_id do |object|
    object.submission.id
  end

  attributes :status

  attribute :ancillary_item_statuses do |object|
    if object.job_class.include?('526')
      object.submission.form526_job_statuses.map do |status|
        status.attributes.except('form526_submission_id') unless status.id == object.id
      end.compact
    end
  end
end
