# frozen_string_literal: true

class Form526Submission < ActiveRecord::Base
  attr_encrypted(:data, key: Settings.db_encryption_key)

  belongs_to :saved_claim,
    class_name: 'SavedClaim::DisabilityCompensation',
    foreign_key: 'saved_claim_id'

  has_many :form526_job_statuses, dependent: :destroy

  def data_to_h
    @data_hash ||= JSON.parse(data)
  end

  def form526_to_json
    data_to_h['form526'].to_json
  end
end
