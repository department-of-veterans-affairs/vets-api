# frozen_string_literal: true

require 'json_marshal/marshaller'
require 'sentry_logging'

class Form526Submission < ApplicationRecord
  include SentryLogging

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
  attr_encrypted(:birls_ids_tried, key: Settings.db_encryption_key, marshal: true, marshaler: JsonMarshal::Marshaller)

  belongs_to :saved_claim,
             class_name: 'SavedClaim::DisabilityCompensation',
             foreign_key: 'saved_claim_id',
             inverse_of: false

  has_many :form526_job_statuses, dependent: :destroy

  validates(:auth_headers_json, presence: true)

  class Error < StandardError; end
  FORM_526 = 'form526'
  FORM_526_UPLOADS = 'form526_uploads'
  FORM_4142 = 'form4142'
  FORM_0781 = 'form0781'
  FORM_8940 = 'form8940'

  # Kicks off a 526 submit workflow batch. The first step in a submission workflow is to submit
  # an increase only or all claims form. Once the first job succeeds the batch will callback and run
  # one (cleanup job) or more ancillary jobs such as uploading supporting evidence or submitting ancillary forms.
  #
  # @return [String] the job id of the first job in the batch, i.e the 526 submit job
  #
  def start
    workflow_batch = Sidekiq::Batch.new
    workflow_batch.on(
      :success,
      'Form526Submission#perform_ancillary_jobs_handler',
      'submission_id' => id,
      'full_name' => get_full_name
    )
    jids = workflow_batch.jobs do
      EVSS::DisabilityCompensationForm::SubmitForm526AllClaim.perform_async(id)
    end

    jids.first
  end

  # Runs the start method above but first looks to see if the veteran has BIRLS IDs that previous start
  # attempts haven't used before (if so, swaps one of those into auth_headers).
  # If all BIRLS IDs for a veteran have been tried, does nothing and returns nil.
  # Note: this assumes that the current BIRLS ID has been used (that `start` has been attempted once).
  #
  # @return [String] the job id of the first job in the batch, i.e the 526 submit job
  # @return [NilClass] all BIRLS IDs for the veteran have been tried
  #
  def start_but_use_a_birls_id_that_hasnt_been_tried_yet(extra_content_for_sentry = {})
    mark_current_birls_id_as_tried

    birls_id_that_hasnt_been_tried_yet = birls_ids_that_havent_been_tried_yet.first
    return unless birls_id_that_hasnt_been_tried_yet

    self.multiple_birls = true
    self.birls_id = birls_id_that_hasnt_been_tried_yet
    save!
    start
  rescue => e
    # 1) why rescue all errors? 2) why not rethrow the error?
    # This method is primarily intended to be triggered by a running Sidekiq job that has hit a dead end
    # (exhausted, or non-retryable error). One of the places this method is called is inside a
    # `sidekiq_retries_exhausted` block. It seems like the value of self for that block won't be the
    # Sidekiq job instance. Also, rethrowing the error (and letting it bubble up to Sidekiq) might trigger
    # the current job to retry (which we don't want).
    log_exception_to_sentry e, extra_content_for_sentry
  end

  def get_full_name
    user = User.find(user_uuid)
    user&.full_name_normalized&.values&.compact&.join(' ')&.upcase
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
    submission.perform_ancillary_jobs(options['full_name']) if submission.form526_job_statuses.all?(&:success?)
  end

  # Creates a batch for the ancillary jobs, sets up the callback, and adds the jobs to the batch if necessary
  #
  # @param full_name [String] the full name of the user that submitted Form526
  # @return [String] the workflow batch id
  #
  def perform_ancillary_jobs(full_name)
    workflow_batch = Sidekiq::Batch.new
    workflow_batch.on(
      :success,
      'Form526Submission#workflow_complete_handler',
      'submission_id' => id,
      'full_name' => full_name
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
      user = User.find(submission.user_uuid)
      if Flipper.enabled?(:form526_confirmation_email, user)
        submission.send_form526_confirmation_email(options['full_name'])
      end
      submission.workflow_complete = true
      submission.save
    end
  end

  def send_form526_confirmation_email(full_name)
    email_address = form['form526']['form526']['veteran']['emailAddress']
    personalization_parameters = {
      'email' => email_address,
      'submitted_claim_id' => submitted_claim_id,
      'date_submitted' => created_at.strftime('%B %-d, %Y %-l:%M %P %Z').sub(/([ap])m/, '\1.m.'),
      'full_name' => full_name
    }
    Form526ConfirmationEmailJob.perform_async(personalization_parameters)
  end

  def bdd?
    form.dig('form526', 'form526', 'bddQualified') || false
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

  def mark_current_birls_id_as_tried
    raise Error, "can't retrieve current birls_id --no auth_headers" unless auth_headers

    self.birls_ids_tried = [*birls_ids_tried, birls_id]
  end

  def birls_ids_that_havent_been_tried_yet
    all_birls_ids_for_veteran - (birls_ids_tried || [])
  end

  def all_birls_ids_for_veteran
    raise Error, 'no edipi' unless edipi

    accounts = Account.where edipi: edipi
    raise Error, "edipi didn't pull up an account" if accounts.empty?
    raise Error, 'edipi pulled up multiple accounts' if accounts.count > 1

    accounts.first.mvi_find_profile_response.profile.birls_ids
  end

  def edipi
    auth_headers&.dig 'va_eauth_dodedipnid'
  end

  def birls_id
    auth_headers&.dig 'va_eauth_birlsfilenumber'
  end

  def birls_id=(value)
    raise Error, "can't set birls_id --no auth_headers" unless auth_headers

    auth_headers['va_eauth_birlsfilenumber'] = value
    self.auth_headers_json = auth_headers.to_json
  end
end
