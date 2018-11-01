# frozen_string_literal: true

class Form526Submission < ActiveRecord::Base
  attr_encrypted(:data, key: Settings.db_encryption_key)

  belongs_to :saved_claim,
    class_name: 'SavedClaim::DisabilityCompensation',
    foreign_key: 'saved_claim_id'

  has_many :form526_job_statuses, dependent: :destroy

  attr_accessor :auth_headers_hash, :form_hash

  after_initialize do |submission|
    submission.auth_headers_hash = JSON.parse(submission.auth_headers)
    submission.form_hash = JSON.parse(submission.form)
  end

  def self.create_submission(user, auth_headers, saved_claim)
    Form526Submission.create(
      user_uuid: user.uuid,
      saved_claim_id: saved_claim.id,
      auth_headers: auth_headers.to_json,
      form: saved_claim.to_submission_data(user)
    )
  end

  def start(klass)
    workflow_batch = Sidekiq::Batch.new
    workflow_batch.on(
      :success,
      'EVSS::DisabilityCompensationForm::SubmitForm526#workflow_complete_handler',
      'saved_claim_id' => saved_claim_id
    )
    jids = workflow_batch.jobs do
      klass.perform_async(id)
    end
    jids.first
  end

  def perform_ancillary_jobs(bid)
    workflow_batch = Sidekiq::Batch.new(bid)
    workflow_batch.jobs do
      submit_uploads if has_ancillary_item? SavedClaim::DisabilityCompensation::ITEMS[:uploads]
      submit_form_4142 if has_ancillary_item? SavedClaim::DisabilityCompensation::ITEMS[:form4142]
      submit_form_0781 if has_ancillary_item? SavedClaim::DisabilityCompensation::ITEMS[:form0781]
      cleanup
    end
  end

  private

  def has_ancillary_item?(item)
    form_hash[item].present?
  end

  def form_to_json(form)
    form_hash[form].to_json
  end

  def submit_uploads
    form_hash[SavedClaim::DisabilityCompensation::ITEMS[:uploads]].each do |upload_data|
      EVSS::DisabilityCompensationForm::SubmitUploads.perform_async(id, upload_data)
    end
  end

  def submit_form_4142
    CentralMail::SubmitForm4142Job.perform_async(id)
  end

  def submit_form_0781
    EVSS::DisabilityCompensationForm::SubmitForm0781.perform_async(id)
  end

  def cleanup
    EVSS::DisabilityCompensationForm::SubmitForm526Cleanup.perform_async(id)
  end
end
