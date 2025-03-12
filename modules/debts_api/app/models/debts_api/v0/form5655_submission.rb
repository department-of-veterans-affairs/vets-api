# frozen_string_literal: true

require 'user_profile_attribute_service'

module DebtsApi
  class V0::Form5655Submission < ApplicationRecord
    class StaleUserError < StandardError; end
    STATS_KEY = 'api.fsr_submission'
    SUBMISSION_FAILURE_EMAIL_TEMPLATE_ID = Settings.vanotify.services.dmc.template_id.fsr_failed_email
    enum :state, { unassigned: 0, in_progress: 1, submitted: 2, failed: 3 }

    self.table_name = 'form5655_submissions'
    validates :user_uuid, presence: true
    belongs_to :user_account, dependent: nil, optional: true
    has_kms_key
    has_encrypted :form_json, :metadata, :ipf_data, key: :kms_key, **lockbox_options

    def kms_encryption_context
      {
        model_name: 'Form5655Submission',
        model_id: id
      }
    end

    scope :with_debt_type, ->(type) { where("public_metadata ->> 'debt_type' = ?", type) }
    scope :with_flags, ->(flag_array) { where("public_metadata -> 'flags' ?| array[:elements]", elements: flag_array) }
    scope :streamlined, -> { where("(public_metadata -> 'streamlined' ->> 'value')::boolean") }
    scope :not_streamlined, -> { where.not("(public_metadata -> 'streamlined' ->> 'value')::boolean") }
    scope :streamlined_unclear, -> { where("(public_metadata -> 'streamlined') IS NULL") }
    scope :streamlined_nil, lambda {
                              where("(public_metadata -> 'streamlined') IS NOT NULL and " \
                                    "(public_metadata -> 'streamlined' ->> 'value') IS NULL")
                            }

    def public_metadata
      super || {}
    end

    def form
      @form_hash ||= JSON.parse(form_json)
    end

    def ipf_form
      @ipf_form_hash ||= JSON.parse(ipf_data)
    end

    def user_cache_id
      user = User.find(user_uuid)
      raise StaleUserError, user_uuid unless user

      UserProfileAttributeService.new(user).cache_profile_attributes
    end

    def submit_to_vba
      DebtsApi::V0::Form5655::VBASubmissionJob.perform_async(id, user_cache_id)
    end

    def submit_to_vha
      batch = Sidekiq::Batch.new
      batch.on(
        :complete,
        'DebtsApi::V0::Form5655Submission#set_vha_completed_state',
        'submission_id' => id
      )
      batch.jobs do
        DebtsApi::V0::Form5655::VHA::VBSSubmissionJob.perform_async(id, user_cache_id)
        DebtsApi::V0::Form5655::VHA::SharepointSubmissionJob.perform_async(id)
      end
    end

    def set_vha_completed_state(status, options)
      submission = DebtsApi::V0::Form5655Submission.find(options['submission_id'])
      if status.failures.zero?
        submission.submitted!
        StatsD.increment("#{STATS_KEY}.vha.success")
      else
        submission.register_failure("VHA set completed state: #{status.failure_info}")
        StatsD.increment("#{STATS_KEY}.vha.failure")
        Rails.logger.error('Batch FSR Processing Failed', status.failure_info)
      end
    end

    def register_failure(message)
      failed!
      if message.blank?
        message = "An unknown error occurred while submitting the form from call_location: #{caller_locations&.first}"
      end
      update(error_message: message)
      Rails.logger.error("Form5655Submission id: #{id} failed", message)
      StatsD.increment("#{STATS_KEY}.failure")
      StatsD.increment("#{STATS_KEY}.combined.failure") if public_metadata['combined']
      begin
        send_failed_form_email unless message.include?('Sharepoint')
      rescue => e
        StatsD.increment("#{STATS_KEY}.send_failed_form_email.enqueue.failure")
        Rails.logger.error("Failed to send failed form email: #{e.message}")
      end
    end

    def send_failed_form_email
      if Flipper.enabled?(:debts_silent_failure_mailer)
        StatsD.increment("#{STATS_KEY}.send_failed_form_email.enqueue")
        submission_email = ipf_form['personal_data']['email_address'].downcase

        jid = DebtManagementCenter::VANotifyEmailJob.perform_in(
          6.hours,
          submission_email,
          SUBMISSION_FAILURE_EMAIL_TEMPLATE_ID,
          failure_email_personalization_info,
          { id_type: 'email', failure_mailer: true }
        )

        Rails.logger.info("Failed 5655 form: #{id} email scheduled with jid: #{jid}")
      end
    end

    def failure_email_personalization_info
      name_info = ipf_form['personal_data']['veteran_full_name']

      {
        'first_name' => name_info['first'],
        'date_submitted' => Time.zone.now.strftime('%m/%d/%Y'),
        'updated_at' => updated_at,
        'confirmation_number' => id
      }
    end

    def register_success
      submitted!
      StatsD.increment("#{STATS_KEY}.success")
      StatsD.increment("#{STATS_KEY}.combined.success") if public_metadata['combined']
    end

    def streamlined?
      public_metadata.dig('streamlined', 'value') == true
    end

    def upsert_in_progress_form
      form = InProgressForm.find_or_initialize_by(form_id: '5655', user_uuid:)
      form.user_account = user_account_from_uuid(user_uuid)
      form.real_user_uuid = user_uuid

      form.update!(form_data: ipf_data, metadata: fresh_metadata)
    end

    def fresh_metadata
      {
        'return_url' => '/review-and-submit',
        'submission' => {
          'status' => false,
          'error_message' => false,
          'id' => false,
          'timestamp' => false,
          'has_attempted_submit' => false
        },
        'saved_at' => Time.now.to_i,
        'created_at' => Time.now.to_i,
        'expiresAt' => (DateTime.now + 60).to_time.to_i,
        'lastUpdated' => Time.now.to_i,
        'inProgressFormId' => '5655'
      }
    end

    def user_account_from_uuid(user_uuid)
      UserVerification.where(idme_uuid: user_uuid)
                      .or(UserVerification.where(logingov_uuid: user_uuid))
                      .or(UserVerification.where(backing_idme_uuid: user_uuid))
                      .last&.user_account
    end
  end
end
