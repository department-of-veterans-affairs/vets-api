# frozen_string_literal: true

require 'user_profile_attribute_service'
require 'sidekiq/attr_package'

module DebtsApi
  class V0::Form5655Submission < ApplicationRecord
    class StaleUserError < StandardError; end
    STATS_KEY = 'api.fsr_submission'
    SUBMISSION_FAILURE_EMAIL_TEMPLATE_ID = Settings.vanotify.services.dmc.template_id.fsr_failed_email
    FORM_ID = '5655'
    ZSF_DD_TAG_SERVICE = 'debt-resolution'
    ZSF_DD_TAG_FUNCTION = 'register_failure'
    enum :state, { unassigned: 0, in_progress: 1, submitted: 2, failed: 3 }

    self.table_name = 'form5655_submissions'
    validates :user_uuid, presence: true
    belongs_to :user_account, dependent: nil, optional: false
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
      transaction_log = create_transaction_log_if_needed
      StatsD.increment("#{DebtsApi::V0::Form5655::VBASubmissionJob::STATS_KEY}.initiated")
      DebtsApi::V0::Form5655::VBASubmissionJob.perform_async(id, user_cache_id)
      transaction_log&.mark_submitted
    end

    def submit_to_vha
      transaction_log = create_transaction_log_if_needed
      batch = Sidekiq::Batch.new
      batch.on(
        :complete,
        'DebtsApi::V0::Form5655Submission#set_vha_completed_state',
        'submission_id' => id
      )
      batch.jobs do
        DebtsApi::V0::Form5655::VHA::VBSSubmissionJob.perform_async(id, user_cache_id)
        # Delay sharepoint submission to allow VBA to process the form
        unless Flipper.enabled?(:financial_management_vbs_only)
          DebtsApi::V0::Form5655::VHA::SharepointSubmissionJob.perform_in(5.seconds, id)
        end
      end
      transaction_log&.mark_submitted
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
      find_transaction_log&.mark_failed
      Rails.logger.error("Form5655Submission id: #{id} failed", message)
      StatsD.increment("#{STATS_KEY}.failure")
      StatsD.increment("#{STATS_KEY}.combined.failure") if public_metadata['combined']
      begin
        send_failed_form_email unless message.match?(/sharepoint/i)
      rescue => e
        StatsD.increment("#{STATS_KEY}.send_failed_form_email.enqueue.failure")
        Rails.logger.error("Failed to send failed form email: #{e.message}")
      end
    end

    def send_failed_form_email
      StatsD.increment("#{STATS_KEY}.send_failed_form_email.enqueue")
      submission_email = ipf_form['personal_data']['email_address'].downcase
      cache_key = Sidekiq::AttrPackage.create(
        expires_in: 30.days,
        email: submission_email,
        personalisation: failure_email_personalization_info
      )
      jid = DebtManagementCenter::VANotifyEmailJob.perform_in(
        24.hours,
        nil,
        SUBMISSION_FAILURE_EMAIL_TEMPLATE_ID,
        nil,
        { id_type: 'email', failure_mailer: true, cache_key: }
      )

      Rails.logger.info("Failed 5655 email enqueued form: #{id} email scheduled with jid: #{jid}")
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
      find_transaction_log&.mark_completed
      StatsD.increment("#{STATS_KEY}.success")
      StatsD.increment("#{STATS_KEY}.combined.success") if public_metadata['combined']
    end

    def streamlined?
      public_metadata.dig('streamlined', 'value') == true
    end

    def vba_debt_identifiers
      return [] if metadata.blank?

      parsed_metadata = JSON.parse(metadata)
      debts = parsed_metadata['debts'] || []

      debts.map do |debt|
        "#{debt['deductionCode']}#{debt['originalAR'].to_i}"
      end.compact
    rescue JSON::ParserError
      []
    end

    def vha_copay_identifiers
      return [] if metadata.blank?

      parsed_metadata = JSON.parse(metadata)
      copays = parsed_metadata['copays'] || []

      copays.map { |copay| copay['id'] }.compact
    rescue JSON::ParserError
      []
    end

    def debt_identifiers
      # For combined forms, we need to check both debts and copays
      if public_metadata['combined']
        vba_debt_identifiers + vha_copay_identifiers
      elsif public_metadata['debt_type'] == 'DEBT'
        vba_debt_identifiers
      elsif public_metadata['debt_type'] == 'COPAY'
        vha_copay_identifiers
      else
        []
      end
    end

    def upsert_in_progress_form(user_account:)
      form = InProgressForm.find_or_initialize_by(form_id: '5655', user_uuid:)
      form.user_account = user_account
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

    private

    def create_transaction_log_if_needed
      existing_log = find_transaction_log
      return existing_log if existing_log

      user = User.find(user_uuid)
      DebtTransactionLog.track_waiver(self, user)
    end

    def find_transaction_log
      @transaction_log ||= DebtTransactionLog.find_by(
        transactionable: self,
        transaction_type: 'waiver'
      )
    end
  end
end
