# frozen_string_literal: true

module SimpleFormsApi
  class NotificationEmail
    attr_reader :form_number, :confirmation_number, :date_submitted, :lighthouse_updated_at, :notification_type, :user,
                :user_account

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
        error: nil,
        received: nil
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
        error: nil,
        received: nil
      }
    }.freeze
    SUPPORTED_FORMS = TEMPLATE_IDS.keys

    def initialize(config, notification_type: :confirmation, user: nil, user_account: nil)
      check_missing_keys(config)

      @form_data = config[:form_data]
      incoming_form_number = config[:form_number]
      @form_number = if TEMPLATE_IDS.keys.include?(incoming_form_number)
                       incoming_form_number
                     else
                       SimpleFormsApi::V1::UploadsController::FORM_NUMBER_MAP[incoming_form_number]
                     end
      @confirmation_number = config[:confirmation_number]
      @date_submitted = config[:date_submitted]
      @lighthouse_updated_at = config[:lighthouse_updated_at]
      @notification_type = notification_type
      @user = user
      @user_account = user_account
    end

    def send(at: nil)
      return unless SUPPORTED_FORMS.include?(form_number)

      data = form_specific_data || empty_form_specific_data
      return if data[:personalization]['first_name'].blank?

      template_id = TEMPLATE_IDS[form_number][notification_type]
      return unless template_id

      if at
        enqueue_email(at, template_id, data)
      else
        send_email_now(template_id, data)
      end
    end

    private

    def check_missing_keys(config)
      missing_keys = %i[form_data form_number confirmation_number date_submitted].select { |key| config[key].nil? }
      raise ArgumentError, "Missing keys: #{missing_keys.join(', ')}" if missing_keys.any?
    end

    def enqueue_email(at, template_id, data)
      # async job and we have a UserAccount
      if user_account
        data[:personalization]['first_name'] = get_first_name
        return if data[:personalization]['first_name'].blank?

        VANotify::UserAccountJob.perform_at(
          at,
          user_account.id,
          template_id,
          data[:personalization]
        )
      # async job and we don't have a UserAccount but form data should include email
      else
        return if data[:email].blank? || data[:personalization]['first_name'].blank?

        VANotify::EmailJob.perform_at(
          at,
          data[:email],
          template_id,
          data[:personalization]
        )
      end
    end

    def send_email_now(template_id, data)
      # sync job and we have a User
      if user
        return if data[:personalization]['first_name'].blank?

        VANotify::EmailJob.perform_async(
          user.va_profile_email,
          template_id,
          data[:personalization]
        )
      # sync job and form data should include email
      else
        return if data[:email].blank? || data[:personalization]['first_name'].blank?

        VANotify::EmailJob.perform_async(
          data[:email],
          template_id,
          data[:personalization]
        )
      end
    end

    def get_first_name
      if user_account
        mpi_response = MPI::Service.new.find_profile_by_identifier(identifier_type: 'ICN', identifier: user_account.icn)
        if mpi_response
          error = mpi_response.error
          Rails.logger.error('MPI response error', { error: }) if error

          first_name = mpi_response.profile&.given_names&.first
          Rails.logger.error('MPI profile missing first_name') unless first_name

          first_name
        end
      elsif user
        first_name = user.first_name
        Rails.logger.error('First name not found in user profile') unless first_name

        first_name
      end
    end

    # rubocop:disable Metrics/MethodLength
    # email and personalization hash
    def form_specific_data
      case @form_number
      when 'vba_21_0845'
        return unless Flipper.enabled?(:form21_0845_confirmation_email)

        email, first_name = form21_0845_contact_info

        { email:, personalization: default_personalization(first_name) }
      when 'vba_21p_0847'
        return unless Flipper.enabled?(:form21p_0847_confirmation_email)

        {
          email: @form_data['preparer_email'],
          personalization: default_personalization(@form_data.dig('preparer_name', 'first'))
        }
      when 'vba_21_0966'
        return unless Flipper.enabled?(:form21_0966_confirmation_email)

        {
          email: @user&.va_profile_email,
          personalization: default_personalization(get_first_name)
            .merge(form21_0966_personalization)
        }
      when 'vba_21_0972'
        return unless Flipper.enabled?(:form21_0972_confirmation_email)

        {
          email: @form_data['preparer_email'],
          personalization: default_personalization(@form_data.dig('preparer_full_name', 'first'))
        }
      when 'vba_21_4142'
        return unless Flipper.enabled?(:form21_4142_confirmation_email)

        {
          email: @form_data.dig('veteran', 'email'),
          personalization: default_personalization(@form_data.dig('veteran', 'full_name', 'first'))
        }
      when 'vba_21_10210'
        return unless Flipper.enabled?(:form21_10210_confirmation_email)

        email, first_name = form21_10210_contact_info

        { email:, personalization: default_personalization(first_name) }
      when 'vba_20_10206'
        return unless Flipper.enabled?(:form20_10206_confirmation_email)

        email, first_name = form20_10206_contact_info

        { email:, personalization: default_personalization(first_name) }
      when 'vba_20_10207'
        return unless Flipper.enabled?(:form20_10207_confirmation_email)

        email, first_name = form20_10207_contact_info

        { email:, personalization: default_personalization(first_name) }
      when 'vba_40_0247'
        return unless Flipper.enabled?(:form40_0247_confirmation_email)

        {
          email: @form_data['applicant_email'],
          personalization: default_personalization(@form_data.dig('applicant_full_name', 'first'))
        }
      end
    end
    # rubocop:enable Metrics/MethodLength

    def empty_form_specific_data
      { email: '', personalization: {} }
    end

    # personalization hash shared by all simple form confirmation emails
    def default_personalization(first_name)
      {
        'first_name' => first_name&.upcase,
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
      if @form_data['authorizer_type'] == 'veteran' && @user
        [@user.va_profile_email, @form_data.dig('veteran_full_name', 'first')]

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
        email = user&.va_profile_email || @form_data['veteran_email']
        [email, @form_data.dig('veteran_full_name', 'first')]

      # user's own claim
      # user is not a veteran
      elsif @form_data['claim_ownership'] == 'self' && @form_data['claimant_type'] == 'non-veteran'
        email = user&.va_profile_email || @form_data['claimant_email']
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

    def form21_0966_personalization
      benefits = @form_data['benefit_selection']
      intent_to_file_benefits = if benefits['compensation'] && benefits['pension']
                                  'Disability Compensation (VA Form 21-526EZ) and Pension (VA Form 21P-527EZ)'
                                elsif benefits['compensation']
                                  'Disability Compensation (VA Form 21-526EZ)'
                                elsif benefits['pension']
                                  'Pension (VA Form 21P-527EZ)'
                                elsif benefits['survivor']
                                  'Survivors Pension and/or Dependency and Indemnity Compensation (DIC)' \
                                    ' (VA Form 21P-534 or VA Form 21P-534EZ)'
                                end
      { 'intent_to_file_benefits' => intent_to_file_benefits }
    end
  end
end
