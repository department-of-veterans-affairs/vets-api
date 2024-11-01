# frozen_string_literal: true

require 'logging/call_location'
require 'zero_silent_failures/monitor'

class FormSubmissionAttempt < ApplicationRecord
  include AASM

  belongs_to :form_submission
  has_one :saved_claim, through: :form_submission
  has_one :in_progress_form, through: :form_submission
  has_one :user_account, through: :form_submission

  has_kms_key
  has_encrypted :error_message, :response, key: :kms_key, **lockbox_options
  # We only have the ignored_columns here because I haven't yet removed the error_message and
  # response columns from the db. (The correct column names are error_message_ciphertext and response_ciphertext)
  # If we get around to doing that, we shouldn't need the following line.
  self.ignored_columns += %w[error_message response]

  HOUR_TO_SEND_NOTIFICATIONS = 9

  aasm do
    after_all_transitions :log_status_change

    state :pending, initial: true
    state :failure, :success, :vbms
    state :manually

    event :fail do
      after do
        form_type = form_submission.form_type
        log_info = { form_submission_id:,
                     benefits_intake_uuid:,
                     form_type:,
                     user_account_uuid: form_submission.user_account_id }
        if should_send_simple_forms_email
          simple_forms_api_email(log_info)
        elsif form_type == CentralMail::SubmitForm4142Job::FORM4142_FORMSUBMISSION_TYPE
          form526_form4142_email(log_info)
        end
      end

      transitions from: :pending, to: :failure
    end

    event :succeed do
      transitions from: :pending, to: :success
    end

    event :vbms do
      after do
        simple_forms_enqueue_result_email(:received) if should_send_simple_forms_email
      end

      transitions from: :pending, to: :vbms
      transitions from: :success, to: :vbms
    end

    event :remediate do
      transitions from: :failure, to: :vbms
    end

    event :manual do
      transitions from: :failure, to: :manually
    end
  end

  def log_status_change
    log_hash = {
      form_submission_id:,
      benefits_intake_uuid:,
      form_type: form_submission&.form_type,
      from_state: aasm.from_state,
      to_state: aasm.to_state,
      event: aasm.current_event
    }

    case aasm.current_event
    when 'fail!'
      log_hash[:message] = 'Form Submission Attempt failed'
      Rails.logger.error(log_hash)
    when 'vbms!'
      log_hash[:message] = 'Form Submission Attempt went to vbms'
    when 'manual!'
      log_hash[:message] = 'Form Submission Attempt is being manually remediated'
    else
      log_hash[:message] = 'Form Submission Attempt State change'
    end

    Rails.logger.info(log_hash) if aasm.current_event != 'fail!'
  end

  private

  def simple_forms_api_email(log_info)
    Rails.logger.info('Preparing to send Form Submission Attempt error email', log_info)
    simple_forms_enqueue_result_email(:error)
  end

  def queue_form526_form4142_email(form526_submission_id, log_info)
    Rails.logger.info('Queuing Form526:Form4142 failure email to VaNotify',
                      log_info.merge({ form526_submission_id: }))
    jid = EVSS::DisabilityCompensationForm::Form4142DocumentUploadFailureEmail.perform_async(
      form526_submission_id
    )
    Rails.logger.info('Queuing Form526:Form4142 failure email to VaNotify completed',
                      log_info.merge({ jid:, form526_submission_id: }))
  end

  def form526_form4142_email(log_info)
    if Flipper.enabled?(CentralMail::SubmitForm4142Job::POLLED_FAILURE_EMAIL)
      queue_form526_form4142_email(Form526Submission.find_by(saved_claim_id:).id, log_info)
    else
      Rails.logger.info(
        'Would queue EVSS::DisabilityCompensationForm::Form4142DocumentUploadFailureEmail, but flipper is off.',
        log_info.merge({ form526_submission_id: })
      )
    end
  rescue => e
    cl = caller_locations.first
    call_location = Logging::CallLocation.new(
      CentralMail::SubmitForm4142Job::ZSF_DD_TAG_FUNCTION, cl.path, cl.lineno
    )
    ZeroSilentFailures::Monitor.new(Form526Submission::ZSF_DD_TAG_SERVICE).log_silent_failure(
      log_info.merge({ error_class: e.class, error_message: e.message }),
      log_info[:user_account_uuid], call_location:
    )
  end

  def should_send_simple_forms_email
    simple_forms_form_number && Flipper.enabled?(:simple_forms_email_notifications)
  end

  def simple_forms_enqueue_result_email(notification_type)
    raw_form_data = form_submission.form_data || '{}'
    form_data = JSON.parse(raw_form_data)
    config = {
      form_data:,
      form_number: simple_forms_form_number,
      confirmation_number: benefits_intake_uuid,
      date_submitted: created_at.strftime('%B %d, %Y'),
      lighthouse_updated_at: lighthouse_updated_at&.strftime('%B %d, %Y')
    }

    SimpleFormsApi::NotificationEmail.new(
      config,
      notification_type:,
      user_account:
    ).send(at: time_to_send)
  end

  def time_to_send
    now = Time.now.in_time_zone('Eastern Time (US & Canada)')
    if now.hour < HOUR_TO_SEND_NOTIFICATIONS
      now.change(hour: HOUR_TO_SEND_NOTIFICATIONS,
                 min: 0)
    else
      now.tomorrow.change(
        hour: HOUR_TO_SEND_NOTIFICATIONS, min: 0
      )
    end
  end

  def simple_forms_form_number
    @simple_forms_form_number ||=
      if SimpleFormsApi::NotificationEmail::TEMPLATE_IDS.keys.include? form_submission.form_type
        form_submission.form_type
      else
        SimpleFormsApi::V1::UploadsController::FORM_NUMBER_MAP[form_submission.form_type]
      end
  end
end
