# frozen_string_literal: true

class Form526Submission < ActiveRecord::Base
  attr_encrypted(:auth_headers_json, key: Settings.db_encryption_key)
  attr_encrypted(:form_json, key: Settings.db_encryption_key)

  belongs_to :saved_claim,
             class_name: 'SavedClaim::DisabilityCompensation',
             foreign_key: 'saved_claim_id',
             inverse_of: false

  has_many :form526_job_statuses, dependent: :destroy

  FORM_526 = 'form526'
  FORM_526_UPLOADS = 'form526_uploads'
  FORM_4142 = 'form4142'
  FORM_0781 = 'form0781'
  FORM_8940 = 'form8940'

  def start(klass)
    workflow_batch = Sidekiq::Batch.new
    workflow_batch.on(
      :success,
      'Form526Submission#perform_ancillary_jobs_handler',
      'submission_id' => id
    )
    jids = workflow_batch.jobs do
      klass.perform_async(id)
    end

    # submit form 526 is the first job in the batch
    # after it completes ancillary jobs may be added to the workflow batch
    # via the #perform_ancillary_jobs_handler below
    jids.first
  end

  def form
    @form_hash ||= JSON.parse(form_json)
  end

  def form_to_json(item)
    form[item].to_json
  end

  def auth_headers
    @auth_headers_hash ||= JSON.parse(auth_headers_json)
  end

  def perform_ancillary_jobs_handler(status, options)
    submission = Form526Submission.find(options['submission_id'])
    submission.perform_ancillary_jobs(status.parent_bid)
  end

  def perform_ancillary_jobs(bid)
    workflow_batch = Sidekiq::Batch.new(bid)
    workflow_batch.on(
      :success,
      'Form526Submission#workflow_complete_handler',
      'submission_id' => id
    )
    workflow_batch.jobs do
      submit_uploads if form[FORM_526_UPLOADS].present?
      submit_form_4142 if form[FORM_4142].present?
      submit_form_0781 if form[FORM_0781].present?
      submit_form_8940 if form[FORM_8940].present?
      cleanup
    end
  end

  def workflow_complete_handler(_status, options)
    submission = Form526Submission.find(options['submission_id'])
    if submission.form526_job_statuses.all?(&:success?)
      submission.workflow_complete = true
      submission.save
    end
  end

  private

  def submit_uploads
    # Put uploads on a one minute delay because of shared workload with EVSS
    EVSS::DisabilityCompensationForm::SubmitUploads.perform_in(60.seconds, id, form[FORM_526_UPLOADS])
  end

  def submit_form_4142
    CentralMail::SubmitForm4142Job.perform_async(id)
  end

  def submit_form_0781
    EVSS::DisabilityCompensationForm::SubmitForm0781.perform_async(id)
  end

  def submit_form_8940
    EVSS::DisabilityCompensationForm::SubmitForm8940.perform_async(id)
  end

  def cleanup
    EVSS::DisabilityCompensationForm::SubmitForm526Cleanup.perform_async(id)
  end
end
