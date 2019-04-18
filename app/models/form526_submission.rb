# frozen_string_literal: true

class Form526Submission < ApplicationRecord
  # A 526 disability compensation form record. This class is used to persist the post transformation form
  # and track submission workflow steps.
  #
  # @!attribute id
  #   @return [Integer] auto-increment primary key.
  # @!attribute user_uuid
  #   @return [String] points to the user's uuid from the identity provider.
  # @!attribute saved_claim_id
  #   @return [Integer] the related saved claim id {SavedClaim::DisabilityCompensation}.
  # @!attribute auth_headers_json
  #   @return [String] encrypted EVSS auth headers as JSON {EVSS::DisabilityCompensationAuthHeaders}.
  # @!attribute form_json
  #   @return [String] encrypted form submission as JSON.
  # @!attribute workflow_complete
  #   @return [Boolean] are all the steps (jobs {EVSS::DisabilityCompensationForm::Job}) of the submission
  #     workflow complete.
  # @!attribute created_at
  #   @return [Timestamp] created at date.
  # @!attribute workflow_complete
  #   @return [Timestamp] updated at date.
  #
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

  # Kicks off a 526 submit workflow batch. The first step in a submission workflow is to submit
  # an increase only or all claims form. Once the first job succeeds the batch will callback and run
  # one (cleanup job) or more ancillary jobs such as uploading supporting evidence or submitting ancillary forms.
  #
  # @param klass [Class] the submit job class to start with
  #   {EVSS::DisabilityCompensationForm::SubmitForm526IncreaseOnly} or
  #   {EVSS::DisabilityCompensationForm::SubmitForm526IncreaseOnly}
  #
  # @return [String] the job id of the first job in the batch, i.e the 526 submit job
  #
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

    jids.first
  end

  # @return [Hash] parsed version of the form json
  #
  def form
    @form_hash ||= JSON.parse(form_json)
  end

  # A 526 submission can include the 526 form submission, uploads, and ancillary items.
  # This method returns a single item as JSON
  #
  # @param item [String] the item key
  # @return [String] the requested form object as JSON
  #
  def form_to_json(item)
    form[item].to_json
  end

  # @return [Hash] parsed auth headers
  #
  def auth_headers
    @auth_headers_hash ||= JSON.parse(auth_headers_json)
  end

  # The workflow batch success handler
  #
  # @param _status [Sidekiq::Batch::Status] the status of the batch
  # @param options [Hash] payload set in the workflow batch
  #
  def perform_ancillary_jobs_handler(_status, options)
    submission = Form526Submission.find(options['submission_id'])
    # Only run ancillary jobs if submission succeeded
    submission.perform_ancillary_jobs if submission.form526_job_statuses.all?(&:success?)
  end

  # Creates a batch for the ancillary jobs, sets up the callback, and adds the jobs to the batch if necessary
  #
  # @return [String] the workflow batch id
  #
  def perform_ancillary_jobs
    workflow_batch = Sidekiq::Batch.new
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

  # Checks if all workflow steps were successful and if so marks it as complete.
  #
  # @param _status [Sidekiq::Batch::Status] the status of the batch
  # @param options [Hash] payload set in the workflow batch
  #
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
