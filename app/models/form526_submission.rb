# frozen_string_literal: true

class Form526Submission < ActiveRecord::Base
  attr_encrypted(:data, key: Settings.db_encryption_key)

  belongs_to :saved_claim,
    class_name: 'SavedClaim::DisabilityCompensation',
    foreign_key: 'saved_claim_id'

  has_many :form526_job_statuses, dependent: :destroy

  def self.create_submission(user, auth_headers, saved_claim)
    Form526Submission.create(
      user_uuid: user.uuid,
      saved_claim_id: saved_claim.id,
      auth_headers: auth_headers.to_json,
      form: saved_claim.to_submission_data(user)
    )
  end

  def perform_ancillary_jobs(bid, claim_id)
    workflow_batch = Sidekiq::Batch.new(bid)
    workflow_batch.jobs do
      submit_uploads if has_ancillary_item? 'uploads'
      submit_form_4142 if has_ancillary_item? 'form4142'
      submit_form_0781 if has_ancillary_item? 'form0781'
      cleanup
    end
  end

  private

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

  def has_ancillary_item?(item)
    data_to_h[item].present?
  end

  def form_to_json(form)
    data_to_h[form].to_json
  end

  def submit_uploads
    @submission.uploads.each do |upload_data|
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
    EVSS::DisabilityCompensationForm::SubmitForm526Cleanup.perform_async(user_uuid)
  end

  def form_to_h
    @form_hash ||= JSON.parse(form)
  end

  def auth_headers_to_h
    @auth_headers_hash ||= JSON.parse(auth_headers)
  end
end
