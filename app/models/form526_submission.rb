# frozen_string_literal: true

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
  attr_encrypted(:birls_ids_tried, key: Settings.db_encryption_key)

  belongs_to :saved_claim,
             class_name: 'SavedClaim::DisabilityCompensation',
             foreign_key: 'saved_claim_id',
             inverse_of: false

  has_many :form526_job_statuses, dependent: :destroy

  validates(:auth_headers_json, presence: true)

  FORM_526 = 'form526'
  FORM_526_UPLOADS = 'form526_uploads'
  FORM_4142 = 'form4142'
  FORM_0781 = 'form0781'
  FORM_8940 = 'form8940'
  BIRLS_KEY = 'va_eauth_birlsfilenumber'
  SUBMIT_FORM_526_JOB_CLASSES = %w[SubmitForm526AllClaim SubmitForm526].freeze

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
      'first_name' => get_first_name
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
  def start_but_use_a_birls_id_that_hasnt_been_tried_yet!(
    extra_content_for_sentry: {},
    silence_errors_and_log_to_sentry: false
  )
    untried_birls_id = birls_ids_that_havent_been_tried_yet.first
    return unless untried_birls_id

    self.birls_id = untried_birls_id
    save!
    start
  rescue => e
    # 1) why have the 'silence_errors_and_log_to_sentry' option? (why not rethrow the error?)
    # This method is primarily intended to be triggered by a running Sidekiq job that has hit a dead end
    # (exhausted, or non-retryable error). One of the places this method is called is inside a
    # `sidekiq_retries_exhausted` block. It seems like the value of self for that block won't be the
    # Sidekiq job instance (so no access to the log_exception_to_sentry method). Also, rethrowing the error
    # (and letting it bubble up to Sidekiq) might trigger the current job to retry (which we don't want).
    raise unless silence_errors_and_log_to_sentry

    log_exception_to_sentry e, extra_content_for_sentry
  end

  def get_first_name
    user = User.find(user_uuid)
    user&.first_name&.upcase
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

  # this method is for queuing up BIRLS ids in the birls_ids_tried hash,
  # and can also be used for initializing birls_ids_tried.
  # birls_ids_tried has this shape:
  # {
  #   birls_id => [timestamp, timestamp, ...],
  #   birls_id => [timestamp, timestamp, ...], # in practice, will be only 1 timestamp
  #   ...
  # }
  # where each timestamp notes when a submissison job (start) was started
  # with that BIRLS id (birls_id_tried keeps track of which BIRLS id
  # have been tried so far).
  # add_birls_ids does not overwrite birls_ids_tried.
  # example:
  # > sub.birls_ids_tried = { '111' => ['2021-01-01T0000Z'] }
  # > sub.add_birls_ids ['111', '222', '333']
  # > pp sub.birls_ids_tried
  #    {
  #      '111' => ['2021-01-01T0000Z'], # a tried BIRLS ID
  #      '222' => [],  # an untried BIRLS ID
  #      '333' => []   # an untried BIRLS ID
  #    }
  # NOTE: '111' was not cleared
  def add_birls_ids(id_or_ids)
    ids = Array.wrap(id_or_ids).map { |id| id.is_a?(Symbol) ? id.to_s : id }
    hash = birls_ids_tried_hash
    ids.each { |id| hash[id] ||= [] }
    self.birls_ids_tried = hash.to_json
    self.multiple_birls = true if birls_ids.length > 1
    ids
  end

  def birls_ids
    [*birls_ids_tried_hash&.keys, birls_id].compact.uniq
  end

  def birls_ids_tried_hash
    birls_ids_tried.presence&.then { |json| JSON.parse json } || {}
  end

  def mark_birls_id_as_tried(id = birls_id!, timestamp_string: Time.zone.now.iso8601.to_s)
    ids = add_birls_ids id
    hash = birls_ids_tried_hash
    hash[ids.first] << timestamp_string
    self.birls_ids_tried = hash.to_json
    timestamp_string
  end

  def mark_birls_id_as_tried!(*args, **kwargs)
    timestamp_string = mark_birls_id_as_tried(*args, **kwargs)
    save!
    timestamp_string
  end

  def birls_ids_that_havent_been_tried_yet
    add_birls_ids birls_id if birls_id.present?
    birls_ids_tried_hash.select { |_id, timestamps| timestamps.blank? }.keys
  end

  def birls_id!
    auth_headers[BIRLS_KEY]
  end

  def birls_id
    birls_id! if auth_headers_json
  end

  def birls_id=(value)
    headers = JSON.parse(auth_headers_json) || {}
    headers[BIRLS_KEY] = value
    self.auth_headers_json = headers.to_json
    @auth_headers_hash = nil # reset cache
  end

  # The workflow batch success handler
  #
  # @param _status [Sidekiq::Batch::Status] the status of the batch
  # @param options [Hash] payload set in the workflow batch
  #
  def perform_ancillary_jobs_handler(_status, options)
    submission = Form526Submission.find(options['submission_id'])
    # Only run ancillary jobs if submission succeeded
    submission.perform_ancillary_jobs(options['first_name']) if submission.jobs_succeeded?
  end

  def jobs_succeeded?
    a_submit_form_526_job_succeeded? && all_other_jobs_succeeded_if_any?
  end

  class SubmitForm526JobStatusesError < StandardError; end

  def a_submit_form_526_job_succeeded?
    submit_form_526_job_statuses = form526_job_statuses.where(job_class: SUBMIT_FORM_526_JOB_CLASSES).order(:updated_at)
    submit_form_526_job_statuses.presence&.any?(&:success?)
  ensure
    successful = submit_form_526_job_statuses.where(status: 'success').load
    warn = ->(message) { log_message_to_sentry(message, :warn, { form_526_submission_id: id }) }
    warn.call 'There are multiple successful SubmitForm526 job statuses' if successful.size > 1
    if successful.size == 1 && submit_form_526_job_statuses.last.unsuccessful?
      warn.call "There is a successful SubmitForm526 job, but it's not the most recent SubmitForm526 job"
    end
  end

  def all_other_jobs_succeeded_if_any?
    form526_job_statuses.where.not(job_class: SUBMIT_FORM_526_JOB_CLASSES).all?(&:success?)
  end

  # Creates a batch for the ancillary jobs, sets up the callback, and adds the jobs to the batch if necessary
  #
  # @param first_name [String] the first name of the user that submitted Form526
  # @return [String] the workflow batch id
  #
  def perform_ancillary_jobs(first_name)
    workflow_batch = Sidekiq::Batch.new
    workflow_batch.on(
      :success,
      'Form526Submission#workflow_complete_handler',
      'submission_id' => id,
      'first_name' => first_name
    )
    workflow_batch.jobs do
      submit_uploads if form[FORM_526_UPLOADS].present?
      submit_form_4142 if form[FORM_4142].present?
      submit_form_0781 if form[FORM_0781].present?
      submit_form_8940 if form[FORM_8940].present?
      upload_bdd_instructions if bdd?
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
    if submission.jobs_succeeded?
      submission.send_form526_confirmation_email(options['first_name'])
      submission.workflow_complete = true
      submission.save
    end
  end

  def send_form526_confirmation_email(first_name)
    email_address = form['form526']['form526']['veteran']['emailAddress']
    personalization_parameters = {
      'email' => email_address,
      'submitted_claim_id' => submitted_claim_id,
      'date_submitted' => created_at.strftime('%B %-d, %Y %-l:%M %P %Z').sub(/([ap])m/, '\1.m.'),
      'first_name' => first_name
    }
    Form526ConfirmationEmailJob.perform_async(personalization_parameters)
  end

  def bdd?
    form.dig('form526', 'form526', 'bddQualified') || false
  end

  private

  def submit_uploads
    # Put uploads on a one minute delay because of shared workload with EVSS
    uploads = form[FORM_526_UPLOADS]
    delay = 60.seconds
    uploads.each do |upload|
      EVSS::DisabilityCompensationForm::SubmitUploads.perform_in(delay, id, [upload])
      delay += 15.seconds
    end
  end

  def upload_bdd_instructions
    # send BDD instructions
    EVSS::DisabilityCompensationForm::UploadBddInstructions.perform_in(60.seconds, id)
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
