# frozen_string_literal: true

class DisabilityCompensationSubmission < ActiveRecord::Base
  belongs_to(
    :disability_compensation_claim,
    class_name: 'SavedClaim::DisabilityCompensation',
    foreign_key: 'disability_compensation_id'
  )
  belongs_to(
    :disability_compensation_job,
    class_name: 'AsyncTransaction::EVSS::VA526ezSubmitTransaction',
    foreign_key: 'va526ez_submit_transaction_id'
  )
end
