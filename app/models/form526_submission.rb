# frozen_string_literal: true

require 'evss/disability_compensation_form/form526_to_lighthouse_transform'
require 'sentry_logging'
require 'sidekiq/form526_backup_submission_process/submit'
require 'logging/third_party_transaction'
require 'lighthouse/poll_form526_pdf'
require 'scopes/form526_submission_state'

class Form526Submission < ApplicationRecord
  extend Logging::ThirdPartyTransaction::MethodWrapper
  include SentryLogging
  include Form526ClaimFastTrackingConcern
  include Scopes::Form526SubmissionState

  wrap_with_logging(:start_evss_submission_job,
                    :enqueue_backup_submission,
                    :submit_form_4142,
                    :submit_uploads,
                    :submit_form_0781,
                    :submit_form_8940,
                    :upload_bdd_instructions,
                    :submit_flashes,
                    :poll_form526_pdf,
                    :cleanup,
                    additional_class_logs: {
                      action: 'Begin as anciliary 526 submission'
                    },
                    additional_instance_logs: {
                      saved_claim_id: %i[saved_claim id],
                      user_uuid: %i[user_uuid]
                    })

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
  # @!attribute updated_at
  #   @return [Timestamp] updated at date.
  has_kms_key
  has_encrypted :auth_headers_json, :birls_ids_tried, :form_json, key: :kms_key, **lockbox_options

  belongs_to :saved_claim,
             class_name: 'SavedClaim::DisabilityCompensation',
             inverse_of: false

  has_many :form526_job_statuses, dependent: :destroy
  has_many :form526_submission_remediations, dependent: :destroy
  belongs_to :user_account, dependent: nil

  validates(:auth_headers_json, presence: true)
  enum :backup_submitted_claim_status, { accepted: 0, rejected: 1, paranoid_success: 2 }
  enum :submit_endpoint, { evss: 0, claims_api: 1, benefits_intake_api: 2 }

  FORM_526 = 'form526'
  FORM_526_UPLOADS = 'form526_uploads'
  FORM_4142 = 'form4142'
  FORM_0781 = 'form0781'
  FORM_8940 = 'form8940'
  FLASHES = 'flashes'
  BIRLS_KEY = 'va_eauth_birlsfilenumber'
  SUBMIT_FORM_526_JOB_CLASSES = %w[SubmitForm526AllClaim SubmitForm526].freeze
  # MAX_PENDING_TIME aligns with the farthest out expectation given in the LH BI docs,
  # plus 1 week to accomodate for edge cases and our sidekiq jobs
  MAX_PENDING_TIME = 3.weeks
  ZSF_DD_TAG_SERVICE = 'disability-application'

  # the keys of the Toxic Exposure details for each section
  TOXIC_EXPOSURE_DETAILS_MAPPING = {
    'gulfWar1990Details' => %w[afghanistan bahrain egypt iraq israel jordan kuwait neutralzone oman qatar saudiarabia
                               somalia syria uae turkey waters airspace],
    'gulfWar2001Details' => %w[djibouti lebanon uzbekistan yemen airspace],
    'herbicideDetails' => %w[cambodia guam koreandemilitarizedzone johnston laos c123 thailand vietnam],
    'otherExposuresDetails' => %w[asbestos chemical mos mustardgas radiation water],
    'otherHerbicideLocations' => [],
    'specifyOtherExposures' => []
  }.freeze

  # used to track in APMs between systems such as Lighthouse
  # example: can be used as a search parameter in Datadog
  # TODO: follow-up in ticket #93563 to make this more robust, i.e. attempts of jobs, etc.
  def system_transaction_id
    service_provider = saved_claim.parsed_form['startedFormVersion'].present? ? 'lighthouse' : 'evss'
    "Form526Submission_#{id}, user_uuid: #{user_uuid}, service_provider: #{service_provider}"
  end

  # Called when the DisabilityCompensation form controller is ready to hand off to the backend
  # submission process. Currently this passes directly to the retryable EVSS workflow, but if any
  # one-time setup or workflow redirection (e.g. for Claims Fast-Tracking) needs to happen, it should
  # go here and call start_evss_submission_job when done.
  def start
    log_max_cfi_metrics_on_submit
    log_document_type_metrics
    start_evss_submission_job
  end

  # Kicks off a retryable 526 submit workflow. The first step in a submission workflow is to submit
  # an increase only or all claims form. Once the first job succeeds the batch will callback and run
  # one (cleanup job) or more ancillary jobs such as uploading supporting evidence or submitting ancillary forms.
  #
  # @return [String] the job id of the first job in the batch, i.e the 526 submit job
  #
  def start_evss_submission_job
    workflow_batch = Sidekiq::Batch.new
    workflow_batch.on(
      :success,
      'Form526Submission#perform_ancillary_jobs_handler',
      'submission_id' => id,
      # Call get_first_name while the temporary User record still exists
      'first_name' => get_first_name
    )
    job_ids = workflow_batch.jobs do
      EVSS::DisabilityCompensationForm::SubmitForm526AllClaim.perform_async(id)
    end

    job_ids.first
  end

  # Runs start_evss_submission_job but first looks to see if the veteran has BIRLS IDs that previous start
  # attempts haven't used before (if so, swaps one of those into auth_headers).
  # If all BIRLS IDs for a veteran have been tried, does nothing and returns nil.
  # Note: this assumes that the current BIRLS ID has been used (that `start` has been attempted once).
  #
  # @return [String] the job id of the first job in the batch, i.e the 526 submit job
  # @return [NilClass] all BIRLS IDs for the veteran have been tried
  #
  def submit_with_birls_id_that_hasnt_been_tried_yet!(
    extra_content_for_sentry: {},
    silence_errors_and_log_to_sentry: false
  )
    untried_birls_id = birls_ids_that_havent_been_tried_yet.first

    return unless untried_birls_id

    self.birls_id = untried_birls_id
    save!
    start_evss_submission_job
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

  # Note that the User record is cached in Redis -- `User.redis_namespace_ttl`
  def get_first_name
    user&.first_name&.upcase.presence || auth_headers&.dig('va_eauth_firstName')&.upcase
  end

  # Checks against the User record first, and then resorts to checking the auth_headers
  # for the name attributes if the User record doesn't exist or contain the full name
  #
  # @return [Hash] of the user's full name (first, middle, last, suffix)
  #
  def full_name
    name_hash = user&.full_name_normalized
    return name_hash if name_hash&.[](:first).present?

    { first: auth_headers&.dig('va_eauth_firstName')&.capitalize,
      middle: nil,
      last: auth_headers&.dig('va_eauth_lastName')&.capitalize,
      suffix: nil }
  end

  # form_json is memoized here so call invalidate_form_hash after updating form_json
  # @return [Hash] parsed version of the form json
  #
  def form
    @form_hash ||= JSON.parse(form_json)
  end

  # Call this method to invalidate the memoized @form_hash variable after updating form_json.
  # A hook that calls this method could be added so that we don't have to call this manually,
  # see https://stackoverflow.com/questions/24314584/run-a-callback-only-if-an-attribute-has-changed-in-rails
  def invalidate_form_hash
    remove_instance_variable(:@form_hash) if instance_variable_defined?(:@form_hash)
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

  def mark_birls_id_as_tried!(*, **)
    timestamp_string = mark_birls_id_as_tried(*, **)
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

  # Called by Sidekiq::Batch as part of the Form 526 submission workflow
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
      conditionally_submit_form_4142
      submit_form_0781 if form[FORM_0781].present?
      submit_form_8940 if form[FORM_8940].present?
      upload_bdd_instructions if bdd?
      submit_flashes if form[FLASHES].present?
      poll_form526_pdf
      cleanup
    end
  end

  # Called by Sidekiq::Batch as part of the Form 526 submission workflow
  # Checks if all workflow steps were successful and if so marks it as complete.
  #
  # @param _status [Sidekiq::Batch::Status] the status of the batch
  # @param options [Hash] payload set in the workflow batch
  #
  def workflow_complete_handler(_status, options)
    submission = Form526Submission.find(options['submission_id'])
    if submission.jobs_succeeded?
      # If the received_email_from_polling feature enabled, skip this call
      unless Flipper.enabled?(:disability_526_call_received_email_from_polling,
                              OpenStruct.new({ flipper_id: user_uuid }))
        submission.send_received_email('Form526Submission#workflow_complete_handler')
      end
      submission.workflow_complete = true
      submission.save
    else
      params = submission.personalization_parameters(options['first_name'])
      Form526SubmissionFailedEmailJob.perform_async(params)
    end
  end

  def bdd?
    form.dig('form526', 'form526', 'bddQualified') || false
  end

  def personalization_parameters(first_name)
    {
      'email' => form['form526']['form526']['veteran']['emailAddress'],
      # for email templates using VANotify,
      # we can conditionally display fields
      # by sending an empty string through the payload
      'submitted_claim_id' => submitted_claim_id || '',
      'date_submitted' => created_at.strftime('%B %-d, %Y %-l:%M %P %Z').sub(/([ap])m/, '\1.m.'),
      'date_received' => Time.now.utc.strftime('%B %-d, %Y %-l:%M %P %Z').sub(/([ap])m/, '\1.m.'),
      'first_name' => first_name
    }
  end

  def veteran_email_address
    form.dig('form526', 'form526', 'veteran', 'emailAddress')
  end

  def format_creation_time_for_mailers
    # We display dates in mailers in the format "May 1, 2024 3:01 p.m. EDT"
    created_at.strftime('%B %-d, %Y %-l:%M %P %Z').sub(/([ap])m/, '\1.m.')
  end

  # Synchronous access to Lighthouse API validation boolean for 526 submission
  # Because this method hits an external API, there could be
  # exceptions generated for non-200 response codes.
  #
  # If return is false, then the errors are expected to be
  # in the lighthouse_validation_errors Array of Hashes.
  #
  # NOTE: This is a synchronous access to an external API
  #       so should not be used within a request/response workflow.
  #

  def form_content_valid?
    transform_service = EVSS::DisabilityCompensationForm::Form526ToLighthouseTransform.new
    body = transform_service.transform(form['form526'])

    @lighthouse_validation_response = lighthouse_service.validate526(body)

    if lighthouse_validation_response&.status == 200
      true
    else
      mock_lighthouse_response(status: lighthouse_validation_response&.status)
      false
    end
  rescue => e
    handle_validation_error(e)
    false
  end

  # Returns an Array of Hashes when response.status is 422
  # otherwise it's an empty Array.
  #
  # The Array#empty? is true when there are no errors
  # A Hash entry looks like this ...
  # {
  #   "title": "Unprocessable entity",
  #   "detail": "The property / did not contain the required key serviceInformation",
  #   "status": "422",
  #   "source": {
  #     "pointer": "data/attributes/"
  #   }
  # }
  #
  def lighthouse_validation_errors
    if lighthouse_validation_response&.status == 200
      []
    else
      lighthouse_validation_response.body['errors']
    end
  end

  def duplicate?
    last_remediation&.ignored_as_duplicate?
  end

  def remediated?
    last_remediation&.success || false
  end

  def failure_type?
    !success_type? && !in_process?
  end

  def success_type?
    self.class.success_type.exists?(id:)
  end

  def in_process?
    self.class.in_process.exists?(id:)
  end

  def last_remediation
    form526_submission_remediations&.order(:created_at)&.last
  end

  def account
    return user_account if user_account&.icn.present?

    Rails.logger.info("Form526Submission::account - no UserAccount ICN found for user #{user_uuid}")
    # query MPI by EDIPI first & attributes second for user ICN, return in OpenStruct
    get_icn_from_mpi
  end

  # Send the Submitted Email - when the Veteran has clicked the "submit" button in va.gov
  # Primary Path: when the response from getting a claim id is successful
  # Backup Path: when SubmitForm526 Job has exhausted,
  # or when we get a non_retryable_error response from claim establishment flow
  # @param invoker: string where the Received Email trigger is being called from
  def send_submitted_email(invoker)
    if Flipper.enabled?(:disability_526_send_form526_submitted_email)
      Rails.logger.info("Form526SubmittedEmailJob called for user #{user_uuid}, submission: #{id} from #{invoker}")
      first_name = get_first_name
      params = personalization_parameters(first_name)
      Form526SubmittedEmailJob.perform_async(params)
    end
  end

  # Send the Received Confirmation Email - when we have confirmed VBMS can start processing the claim
  # Primary Path: when the poll for PollForm526PDF job is successful
  # Backup Path: when Form526StatusPollingJob reaches "paranoid_success" status
  # @param invoker: string where the Received Email trigger is being called from
  def send_received_email(invoker)
    Rails.logger.info("Form526ConfirmationEmailJob called for user #{user_uuid}, submission: #{id} from #{invoker}")
    first_name = get_first_name
    params = personalization_parameters(first_name)
    Form526ConfirmationEmailJob.perform_async(params)
  end

  private

  def conditionally_submit_form_4142
    if Flipper.enabled?(:disability_compensation_production_tester, OpenStruct.new({ flipper_id: user_uuid }))
      Rails.logger.info("submit_form_4142 call skipped for submission #{id}")
    elsif form[FORM_4142].present?
      submit_form_4142
    end
  end

  attr_accessor :lighthouse_validation_response

  # Setup the Lighthouse service for this user account.
  # Lighthouse calls the user_account.icn the "ID of Veteran"
  #
  def lighthouse_service
    BenefitsClaims::Service.new(account.icn)
  end

  def handle_validation_error(e)
    errors = e.errors if e.respond_to?(:errors)
    detail = errors&.dig(0, :detail)
    status = errors&.dig(0, :status)
    error_msg = "#{detail || e} -- #{e.backtrace[0]}"
    mock_lighthouse_response(status:, error: error_msg)
  end

  def mock_lighthouse_response(status:, error: 'Unknown')
    response_struct = Struct.new(:status, :body)
    mock_response = response_struct.new(status || 609, nil)

    mock_response.body = {
      'errors' => [
        {
          'title' => "Response Status Code '#{mock_response.status}' - #{error}"
        }
      ]
    }

    @lighthouse_validation_response = mock_response
  end

  def queue_central_mail_backup_submission_for_non_retryable_error!(e: nil)
    # Entry-point for backup 526 CMP submission
    #
    # Required criteria to send a backup 526 submission from here:
    # Enabled in settings and flipper
    # Does not have a valid claim ID (through RRD process or otherwise) (protect against dup submissions)
    # Does not have a backup submission ID (protect against dup submissions)
    backup_job_jid = nil
    flipper_sym = :form526_backup_submission_temp_killswitch
    send_backup_submission = Settings.form526_backup.enabled &&
                             Flipper.enabled?(flipper_sym) &&
                             submitted_claim_id.nil? &&
                             backup_submitted_claim_id.nil?

    backup_job_jid = enqueue_backup_submission(id) if send_backup_submission

    log_message = {
      submission_id: id
    }
    log_message['error_class']   = e.class unless e.nil?
    log_message['error_message'] = e.message unless e.nil?
    log_message['backup_job_id'] = backup_job_jid unless backup_job_jid.nil?
    ::Rails.logger.error('Form526 Exhausted or Errored (non-retryable-error-path)', log_message)
  end

  def enqueue_backup_submission(id)
    Sidekiq::Form526BackupSubmissionProcess::Submit.perform_async(id)
  end

  def submit_uploads
    # Put uploads on a one minute delay because of shared workload with EVSS
    uploads = form[FORM_526_UPLOADS]
    delay = 60.seconds
    uploads.each do |upload|
      EVSS::DisabilityCompensationForm::SubmitUploads.perform_in(delay, id, upload)
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

  def submit_flashes
    # Note that the User record is cached in Redis -- `User.redis_namespace_ttl`
    # If this method runs after the TTL, then the flashes will not be applied -- a possible bug.
    BGS::FlashUpdater.perform_async(id) if user && Flipper.enabled?(:disability_compensation_flashes, user)
  end

  def poll_form526_pdf
    # In order to track the status of the 526 PDF upload via Lighthouse,
    # call poll_form526_pdf, provided we received a valid claim_id from Lighthouse
    if saved_claim.parsed_form['startedFormVersion'].present? && submitted_claim_id
      Lighthouse::PollForm526Pdf.perform_async(id)
    end
  end

  def cleanup
    EVSS::DisabilityCompensationForm::SubmitForm526Cleanup.perform_async(id)
  end

  def get_icn_from_mpi
    edipi_response_profile = edipi_mpi_profile_query(auth_headers['va_eauth_dodedipnid'])
    if edipi_response_profile&.icn.present?
      OpenStruct.new(icn: edipi_response_profile.icn)
    else
      Rails.logger.info("Form526Submission::account - unable to look up MPI profile with EDIPI for user #{user_uuid}")
      attributes_response_profile = attributes_mpi_profile_query(auth_headers)
      if attributes_response_profile&.icn.present?
        OpenStruct.new(icn: attributes_response_profile.icn)
      else
        Rails.logger.info("Form526Submission::account - no ICN present for user #{user_uuid}")
        OpenStruct.new(icn: nil)
      end
    end
  end

  def edipi_mpi_profile_query(edipi)
    return unless edipi

    edipi_response = mpi_service.find_profile_by_edipi(edipi:)
    edipi_response.profile if edipi_response.ok? && edipi_response.profile.icn.present?
  end

  def attributes_mpi_profile_query(auth_headers)
    required_attributes = %w[va_eauth_firstName va_eauth_lastName va_eauth_birthdate va_eauth_pnid]
    return unless required_attributes.all? { |attr| auth_headers[attr].present? }

    attributes_response = mpi_service.find_profile_by_attributes(
      first_name: auth_headers['va_eauth_firstName'],
      last_name: auth_headers['va_eauth_lastName'],
      birth_date: auth_headers['va_eauth_birthdate']&.to_date.to_s,
      ssn: auth_headers['va_eauth_pnid']
    )
    attributes_response.profile if attributes_response.ok? && attributes_response.profile.icn.present?
  end

  def mpi_service
    @mpi_service ||= MPI::Service.new
  end

  def user
    @user ||= User.find(user_uuid)
  end
end
