# frozen_string_literal: true

module SimpleFormsApi
  module Notification
    class Email
      attr_reader :form_number, :confirmation_number, :date_submitted, :expiration_date, :lighthouse_updated_at,
                  :notification_type, :user, :user_account, :form_data

      TEMPLATE_IDS = {
        'vba_21_0845' => {
          confirmation: Settings.vanotify.services.va_gov.template_id.form21_0845_confirmation_email,
          error: Settings.vanotify.services.va_gov.template_id.form21_0845_error_email,
          received: Settings.vanotify.services.va_gov.template_id.form21_0845_received_email
        },
        'vba_21p_0847' => {
          confirmation: Settings.vanotify.services.va_gov.template_id.form21p_0847_confirmation_email,
          error: Settings.vanotify.services.va_gov.template_id.form21p_0847_error_email,
          received: Settings.vanotify.services.va_gov.template_id.form21p_0847_received_email
        },
        'vba_21_0966' => {
          confirmation: Settings.vanotify.services.va_gov.template_id.form21_0966_confirmation_email,
          error: Settings.vanotify.services.va_gov.template_id.form21_0966_error_email,
          received: Settings.vanotify.services.va_gov.template_id.form21_0966_received_email
        },
        'vba_21_0966_intent_api' => {
          received: Settings.vanotify.services.va_gov.template_id.form21_0966_itf_api_received_email
        },
        'vba_21_0972' => {
          confirmation: Settings.vanotify.services.va_gov.template_id.form21_0972_confirmation_email,
          error: Settings.vanotify.services.va_gov.template_id.form21_0972_error_email,
          received: Settings.vanotify.services.va_gov.template_id.form21_0972_received_email
        },
        'vba_21_4142' => {
          confirmation: Settings.vanotify.services.va_gov.template_id.form21_4142_confirmation_email,
          error: Settings.vanotify.services.va_gov.template_id.form21_4142_error_email,
          received: Settings.vanotify.services.va_gov.template_id.form21_4142_received_email
        },
        'vba_21_10210' => {
          confirmation: Settings.vanotify.services.va_gov.template_id.form21_10210_confirmation_email,
          error: Settings.vanotify.services.va_gov.template_id.form21_10210_error_email,
          received: Settings.vanotify.services.va_gov.template_id.form21_10210_received_email
        },
        'vba_20_10206' => {
          confirmation: Settings.vanotify.services.va_gov.template_id.form20_10206_confirmation_email,
          error: Settings.vanotify.services.va_gov.template_id.form20_10206_error_email,
          received: Settings.vanotify.services.va_gov.template_id.form20_10206_received_email
        },
        'vba_20_10207' => {
          confirmation: Settings.vanotify.services.va_gov.template_id.form20_10207_confirmation_email,
          error: Settings.vanotify.services.va_gov.template_id.form20_10207_error_email,
          received: Settings.vanotify.services.va_gov.template_id.form20_10207_received_email
        },
        'vba_40_0247' => {
          confirmation: Settings.vanotify.services.va_gov.template_id.form40_0247_confirmation_email,
          error: Settings.vanotify.services.va_gov.template_id.form40_0247_error_email,
          received: nil
        },
        'vba_40_10007' => {
          confirmation: nil,
          error: Settings.vanotify.services.va_gov.template_id.form40_10007_error_email,
          received: nil
        },
        'vba_26_4555' => {
          confirmation: Settings.vanotify.services.va_gov.template_id.form26_4555_confirmation_email,
          rejected: Settings.vanotify.services.va_gov.template_id.form26_4555_rejected_email,
          duplicate: Settings.vanotify.services.va_gov.template_id.form26_4555_duplicate_email
        }
      }.freeze
      SUPPORTED_FORMS = TEMPLATE_IDS.keys

      def initialize(config, notification_type: :confirmation, user: nil, user_account: nil)
        @notification_type = notification_type

        check_missing_keys(config)
        check_if_form_is_supported(config)

        @form_data = config[:form_data]
        @form_number = config[:form_number]
        @confirmation_number = config[:confirmation_number]
        @date_submitted = config[:date_submitted]
        @expiration_date = config[:expiration_date]
        @lighthouse_updated_at = config[:lighthouse_updated_at]
        @user = user
        @user_account = user_account
      end

      def send(at: nil)
        return unless flipper?

        template_id = TEMPLATE_IDS[form_number][notification_type]
        return unless template_id

        sent_to_va_notify = if at
                              enqueue_email(at, template_id)
                            else
                              send_email_now(template_id)
                            end
        StatsD.increment('silent_failure', tags: statsd_tags) if error_notification? && !sent_to_va_notify
      end

      private

      def check_missing_keys(config)
        all_keys = %i[form_data form_number date_submitted]
        all_keys << :confirmation_number if needs_confirmation_number?
        all_keys << :expiration_date if config[:form_number] == 'vba_21_0966_intent_api'

        missing_keys = all_keys.select { |key| config[key].nil? || config[key].to_s.strip.empty? }

        if missing_keys.any?
          StatsD.increment('silent_failure', tags: statsd_tags) if error_notification?
          raise ArgumentError, "Missing keys: #{missing_keys.join(', ')}"
        end
      end

      def check_if_form_is_supported(config)
        unless SUPPORTED_FORMS.include?(config[:form_number])
          StatsD.increment('silent_failure', tags: statsd_tags) if error_notification?
          raise ArgumentError, "Unsupported form: given form number was #{config[:form_number]}"
        end
      end

      def flipper?
        number = form_number
        number = 'vba_21_0966' if form_number.start_with? 'vba_21_0966'
        Flipper.enabled?(:"form#{number.gsub('vba_', '')}_confirmation_email")
      end

      def enqueue_email(at, template_id)
        email_from_form_data = get_email_address_from_form_data
        first_name_from_form_data = get_first_name_from_form_data

        # async job and form data includes email
        if email_from_form_data && first_name_from_form_data
          async_job_with_form_data(email_from_form_data, first_name_from_form_data, at, template_id)
        # async job and we have a UserAccount
        elsif user_account
          async_job_with_user_account(user_account, at, template_id)
        end
      end

      def async_job_with_form_data(email, first_name, at, template_id)
        if Flipper.enabled?(:simple_forms_notification_callbacks)
          VANotify::EmailJob.perform_at(
            at,
            email,
            template_id,
            get_personalization(first_name),
            *email_args
          )
        else
          VANotify::EmailJob.perform_at(
            at,
            email,
            template_id,
            get_personalization(first_name)
          )
        end
      end

      def async_job_with_user_account(user_account, at, template_id)
        first_name_from_user_account = get_first_name_from_user_account
        return unless first_name_from_user_account

        if Flipper.enabled?(:simple_forms_notification_callbacks)
          VANotify::UserAccountJob.perform_at(
            at,
            user_account.id,
            template_id,
            get_personalization(first_name_from_user_account),
            *email_args
          )
        else
          VANotify::UserAccountJob.perform_at(
            at,
            user_account.id,
            template_id,
            get_personalization(first_name_from_user_account)
          )
        end
      end

      def send_email_now(template_id)
        email_from_form_data = get_email_address_from_form_data
        first_name_from_form_data = get_first_name_from_form_data

        # sync job and form data includes email
        if email_from_form_data && first_name_from_form_data
          VANotify::EmailJob.perform_async(
            email_from_form_data,
            template_id,
            get_personalization(first_name_from_form_data)
          )
        # sync job and we have a User
        elsif user
          first_name = get_first_name_from_form_data || get_first_name_from_user
          return unless first_name

          VANotify::EmailJob.perform_async(
            user.va_profile_email,
            template_id,
            get_personalization(first_name)
          )
        end
      end

      def get_email_address_from_form_data
        case @form_number
        when 'vba_21_0845'
          form21_0845_contact_info[0]
        when 'vba_21p_0847', 'vba_21_0972'
          form_data['preparer_email']
        when 'vba_21_0966', 'vba_21_0966_intent_api'
          form21_0966_email_address
        when 'vba_21_4142', 'vba_26_4555'
          form_data.dig('veteran', 'email')
        when 'vba_21_10210'
          form21_10210_contact_info[0]
        when 'vba_20_10206'
          form20_10206_contact_info[0]
        when 'vba_20_10207'
          form20_10207_contact_info[0]
        when 'vba_40_0247'
          form_data['applicant_email']
        when 'vba_40_10007'
          form_data.dig('application', 'claimant', 'email')
        end
      end

      # rubocop:disable Metrics/MethodLength
      def get_first_name_from_form_data
        case @form_number
        when 'vba_21_0845'
          form21_0845_contact_info[1]
        when 'vba_21p_0847'
          form_data.dig('preparer_name', 'first')
        when 'vba_21_0966', 'vba_21_0966_intent_api'
          form21_0966_first_name
        when 'vba_21_0972'
          form_data.dig('preparer_full_name', 'first')
        when 'vba_21_4142', 'vba_26_4555'
          form_data.dig('veteran', 'full_name', 'first')
        when 'vba_21_10210'
          form21_10210_contact_info[1]
        when 'vba_20_10206'
          form20_10206_contact_info[1]
        when 'vba_20_10207'
          form20_10207_contact_info[1]
        when 'vba_40_0247'
          form_data.dig('applicant_full_name', 'first')
        when 'vba_40_10007'
          form40_10007_first_name
        end
      end
      # rubocop:enable Metrics/MethodLength

      def get_first_name_from_user_account
        mpi_response = MPI::Service.new.find_profile_by_identifier(identifier_type: 'ICN', identifier: user_account.icn)
        if mpi_response
          error = mpi_response.error
          Rails.logger.error('MPI response error', { error: }) if error

          first_name = mpi_response.profile&.given_names&.first
          Rails.logger.error('MPI profile missing first_name') unless first_name

          first_name
        end
      end

      def get_first_name_from_user
        first_name = user.first_name
        Rails.logger.error('First name not found in user profile') unless first_name

        first_name
      end

      def get_personalization(first_name)
        personalization = if @form_number.start_with? 'vba_21_0966'
                            default_personalization(first_name).merge(form21_0966_personalization)
                          else
                            default_personalization(first_name)
                          end
        personalization.except!('lighthouse_updated_at') unless lighthouse_updated_at
        personalization.except!('confirmation_number') unless confirmation_number
        personalization
      end

      # personalization hash shared by all simple form confirmation emails
      def default_personalization(first_name)
        {
          'first_name' => first_name&.titleize,
          'date_submitted' => date_submitted,
          'confirmation_number' => confirmation_number,
          'lighthouse_updated_at' => lighthouse_updated_at
        }
      end

      # email and first name for form 20-10206
      def form20_10206_contact_info
        # email address not required and omitted
        if @form_data['email_address'].blank? && @user
          [@user.va_profile_email, @form_data.dig('full_name', 'first')]

        # email address not required and optionally entered
        else
          [@form_data['email_address'], @form_data.dig('full_name', 'first')]
        end
      end

      # email and first name for form 20-10207
      def form20_10207_contact_info
        preparer_types = %w[veteran third-party-veteran non-veteran third-party-non-veteran]

        return unless preparer_types.include?(@form_data['preparer_type'])

        email_and_first_name = [@user&.va_profile_email]
        # veteran
        email_and_first_name << if @form_data['preparer_type'] == 'veteran'
                                  @form_data['veteran_full_name']['first']

                                # non-veteran
                                elsif @form_data['preparer_type'] == 'non-veteran'
                                  @form_data['non_veteran_full_name']['first']

                                  # third-party
                                else
                                  @form_data['third_party_full_name']['first']
                                end

        email_and_first_name
      end

      # email and first name for form 21-0845
      def form21_0845_contact_info
        # (vet && signed in)
        if @form_data['authorizer_type'] == 'veteran'
          [@form_data['veteran_email'] || @user&.va_profile_email, @form_data.dig('veteran_full_name', 'first')]

        # (non-vet && signed in) || (non-vet && anon)
        elsif @form_data['authorizer_type'] == 'nonVeteran'
          [@form_data['authorizer_email'], @form_data.dig('authorizer_full_name', 'first')]

        # (vet && anon)
        else
          [nil, nil]
        end
      end

      # email and first name for form 21-10210
      def form21_10210_contact_info
        # user's own claim
        # user is a veteran
        if @form_data['claim_ownership'] == 'self' && @form_data['claimant_type'] == 'veteran'
          email = @form_data['veteran_email'] || user&.va_profile_email
          [email, @form_data.dig('veteran_full_name', 'first')]

        # user's own claim
        # user is not a veteran
        elsif @form_data['claim_ownership'] == 'self' && @form_data['claimant_type'] == 'non-veteran'
          email = @form_data['claimant_email'] || user&.va_profile_email
          [email, @form_data.dig('claimant_full_name', 'first')]

        # someone else's claim
        # claimant (aka someone else) is a veteran
        # or
        # claimant (aka someone else) is not a veteran
        elsif @form_data['claim_ownership'] == 'third-party'
          [@form_data['witness_email'], @form_data.dig('witness_full_name', 'first')]

        else
          [nil, nil]
        end
      end

      def form21_0966_first_name
        if form_data['preparer_identification'] == 'SURVIVING_DEPENDENT'
          form_data.dig('surviving_dependent_full_name', 'first')
        else
          form_data.dig('veteran_full_name', 'first') || user&.first_name
        end
      end

      def form21_0966_email_address
        if form_data['preparer_identification'] == 'SURVIVING_DEPENDENT'
          form_data['surviving_dependent_email']
        else
          form_data['veteran_email']
        end
      end

      def form21_0966_personalization
        intent_to_file_benefits, intent_to_file_benefits_links = get_intent_to_file_benefits_variables
        {
          'intent_to_file_benefits' => intent_to_file_benefits,
          'intent_to_file_benefits_links' => intent_to_file_benefits_links,
          'itf_api_expiration_date' => expiration_date
        }
      end

      def get_intent_to_file_benefits_variables
        benefits = @form_data['benefit_selection']
        if benefits['compensation'] && benefits['pension']
          ['disability compensation and Veterans pension benefits',
           '[File for disability compensation (VA Form 21-526EZ)]' \
           '(https://www.va.gov/disability/file-disability-claim-form-21-526ez/introduction) and [Apply for Veterans ' \
           'Pension benefits (VA Form 21P-527EZ)](https://www.va.gov/find-forms/about-form-21p-527ez/)']
        elsif benefits['compensation']
          ['disability compensation',
           '[File for disability compensation (VA Form 21-526EZ)](https://www.va.gov/disability/file-disability-claim-form-21-526ez/introduction)']
        elsif benefits['pension']
          ['Veterans pension benefits',
           '[Apply for Veterans Pension benefits (VA Form 21P-527EZ)](https://www.va.gov/find-forms/about-form-21p-527ez/)']
        elsif benefits['survivor']
          ['survivors pension benefits',
           '[Apply for DIC, Survivors Pension, and/or Accrued Benefits (VA Form 21P-534EZ)](https://www.va.gov/find-forms/about-form-21p-534ez/)']
        end
      end

      def form40_10007_first_name
        applicant_relationship = form_data.dig('application', 'applicant', 'applicant_relationship_to_claimant')

        if applicant_relationship == 'Self'
          form_data.dig('application', 'claimant', 'name', 'first')
        else
          form_data.dig('application', 'applicant', 'name', 'first')
        end
      end

      def email_args
        [
          Settings.vanotify.services.va_gov.api_key,
          { callback_metadata: { notification_type:, form_number:, confirmation_number:, statsd_tags: } }
        ]
      end

      def statsd_tags
        { 'service' => 'veteran-facing-forms', 'function' => "#{form_number} form submission to Lighthouse" }
      end

      def error_notification?
        notification_type == :error
      end

      def needs_confirmation_number?
        # All email templates require confirmation_number except :duplicate for 26-4555 (SAHSHA)
        # Only 26-4555 supports the :duplicate notification_type
        notification_type != :duplicate
      end
    end
  end
end
