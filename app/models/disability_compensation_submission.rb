# frozen_string_literal: true

class DisabilityCompensationSubmission < ActiveRecord::Base
  belongs_to :disability_compensation_claim,
             class_name: 'SavedClaim::DisabilityCompensation',
             foreign_key: 'disability_compensation_id'

  belongs_to :disability_compensation_job,
             class_name: 'AsyncTransaction::EVSS::VA526ezSubmitTransaction',
             foreign_key: 'va526ez_submit_transaction_id'

  has_many :disability_compensation_job_statuses,
           class_name: 'DisabilityCompensationJobStatus',
           foreign_key: 'disability_compensation_submission_id',
           dependent: :destroy

  alias_attribute :saved_claim, :disability_compensation_claim
  alias_attribute :async_transaction, :disability_compensation_job
  alias_attribute :job_statuses, :disability_compensation_job_statuses
end
