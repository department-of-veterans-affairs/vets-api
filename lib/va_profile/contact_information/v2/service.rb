# frozen_string_literal: true

require 'common/client/concerns/monitoring'
require 'common/client/errors'
require 'va_profile/service'
require 'va_profile/stats'
require 'va_profile/person_settings/service'
require_relative 'configuration'
require_relative 'transaction_response'
require_relative 'person_response'

module VAProfile
  module ContactInformation
    module V2
      class Service < VAProfile::Service
        CONTACT_INFO_CHANGE_TEMPLATE = Settings.vanotify.services.va_gov.template_id.contact_info_change
        VA_PROFILE_ID_POSTFIX = '^PI^200VETS^USDVA'
        EMAIL_PERSONALISATIONS = {
          address: 'Address',
          residence_address: 'Home address',
          correspondence_address: 'Mailing address',
          email: 'Email address',
          phone: 'Phone number',
          home_phone: 'Home phone number',
          mobile_phone: 'Mobile phone number',
          work_phone: 'Work phone number'
        }.freeze

        include Common::Client::Concerns::Monitoring

        configuration VAProfile::ContactInformation::V2::Configuration

        # GET's a Person bio from the VAProfile API
        # If a user is not found in VAProfile, an empty PersonResponse with a 404 status will be returned
        # @return [VAProfile::ContactInformation::V2::PersonResponse] wrapper around an person object
        def get_person
          with_monitoring do
            verify_vet360_id!

            raw_response = perform(:get, "#{MPI::Constants::VA_ROOT_OID}/#{ERB::Util.url_encode(vet360_aaid)}")
            PersonResponse.from(raw_response)
          end
        rescue Common::Client::Errors::ClientError => e
          if e.status == 404
            log_exception_to_sentry(
              e,
              { vet360_id: @user&.vet360_id },
              { va_profile: :person_not_found },
              :warning
            )

            return PersonResponse.new(404, person: nil)
          elsif e.status.to_i >= 400 && e.status.to_i < 500
            return PersonResponse.new(e.status, person: nil)
          end

          handle_error(e)
        rescue => e
          handle_error(e)
        end

        def self.get_person(vet360_id)
          stub_user = OpenStruct.new(vet360_id:)
          new(stub_user).get_person
        end

        def update_address(address)
          address_type =
            if address.address_pou == VAProfile::Models::BaseAddress::RESIDENCE
              'residential'
            else
              'mailing'
            end
          update_model(address, "#{address_type}_address", 'address')
        end

        def update_email(email)
          update_model(email, 'email', 'email')
        end

        def update_telephone(telephone)
          phone_type =
            case telephone.phone_type
            when VAProfile::Models::Telephone::MOBILE
              'mobile_phone'
            when VAProfile::Models::Telephone::HOME
              'home_phone'
            when VAProfile::Models::Telephone::WORK
              'work_phone'
            when VAProfile::Models::Telephone::FAX
              'fax_number'
            when VAProfile::Models::Telephone::TEMPORARY
              'temporary_phone'
            else
              raise 'invalid phone type'
            end

          update_model(telephone, phone_type, 'telephone')
        end

        # POSTs a new address to the VAProfile API
        # @param address [VAProfile::Models::Address] the address to create
        # @return [VAProfile::ContactInformation::V2::AddressTransactionResponse] wrapper around
        #   an transaction object
        def post_address(address)
          post_or_put_data(:post, address, 'addresses', AddressTransactionResponse)
        end

        # PUTs an updated address to the VAProfile API
        # @param address [VAProfile::Models::Address] the address to update
        # @return [VAProfile::ContactInformation::V2::AddressTransactionResponse] wrapper around a transaction object
        def put_address(address)
          post_or_put_data(:put, address, 'addresses', AddressTransactionResponse)
        end

        # GET's the status of an address transaction from the VAProfile api
        # @param transaction_id [int] the transaction_id to check
        # @return [VAProfile::ContactInformation::V2::EmailTransactionResponse] wrapper around a transaction object
        def get_address_transaction_status(transaction_id)
          route = "addresses/status/#{transaction_id}"
          transaction_status = get_transaction_status(route, AddressTransactionResponse)
          changes = transaction_status.changed_field

          send_contact_change_notification(transaction_status, changes)

          transaction_status
        end

        # POSTs a new address to the VAProfile API
        # @param email [VAProfile::Models::Email] the email to create
        # @return [VAProfile::ContactInformation::V2::EmailTransactionResponse] wrapper around an transaction object
        def post_email(email)
          post_or_put_data(:post, email, 'emails', EmailTransactionResponse)
        end

        # PUTs an updated address to the VAProfile API
        # @param email [VAProfile::Models::Email] the email to update
        # @return [VAProfile::ContactInformation::V2::EmailTransactionResponse] wrapper around a transaction object
        def put_email(email)
          old_email =
            begin
              @user.va_profile_email
            rescue
              nil
            end

          response = post_or_put_data(:put, email, 'emails', EmailTransactionResponse)

          transaction = response.transaction
          # Only store old_email if the email address is actually changing.
          # This prevents sending "email changed" notifications when users
          # are only confirming their existing email address (confirmation_date update).
          if transaction.received? && old_email.present? && !old_email.casecmp?(email.email_address)
            OldEmail.create(transaction_id: transaction.id,
                            email: old_email)
          end

          response
        end

        # GET's the status of an email transaction from the VAProfile api
        # @param transaction_id [int] the transaction_id to check
        # @return [VAProfile::ContactInformation::V2::EmailTransactionResponse] wrapper around a transaction object
        def get_email_transaction_status(transaction_id)
          route = "emails/status/#{transaction_id}"
          transaction_status = get_transaction_status(route, EmailTransactionResponse)

          send_email_change_notification(transaction_status)

          transaction_status
        end

        # POSTs a new telephone to the VAProfile API
        # @param telephone [VAProfile::Models::Telephone] the telephone to create
        # @return [VAProfile::ContactInformation::V2::TelephoneUpdateResponse] wrapper around a transaction object
        def post_telephone(telephone)
          post_or_put_data(:post, telephone, 'telephones', TelephoneTransactionResponse)
        end

        # PUTs an updated telephone to the VAProfile API
        # @param telephone [VAProfile::Models::Telephone] the telephone to update
        # @return [VAProfile::ContactInformation::V2::TelephoneUpdateResponse] wrapper around a transaction object
        def put_telephone(telephone)
          post_or_put_data(:put, telephone, 'telephones', TelephoneTransactionResponse)
        end

        # GET's the status of a telephone transaction from the VAProfile api
        # @param transaction_id [int] the transaction_id to check
        # @return [VAProfile::ContactInformation::V2::TelephoneTransactionResponse] wrapper around
        #   a transaction object
        def get_telephone_transaction_status(transaction_id)
          route = "telephones/status/#{transaction_id}"
          transaction_status = get_transaction_status(route, TelephoneTransactionResponse)

          changes = transaction_status.changed_field
          send_contact_change_notification(transaction_status, changes)

          transaction_status
        end

        # GET's the status of a person transaction from the VAProfile api. Does not validate the presence of
        # user's icn before making the service call, as POSTing a person initializes a icn.
        #
        # @param transaction_id [String] the transaction_id to check
        # @return [VAProfile::ContactInformation::V2::PersonTransactionResponse] wrapper around a transaction object
        #
        def get_person_transaction_status(transaction_id)
          with_monitoring do
            raw_response = perform(:get, "status/#{transaction_id}")
            VAProfile::Stats.increment_transaction_results(raw_response, 'init_va_profile')

            VAProfile::ContactInformation::V2::PersonTransactionResponse.from(raw_response, @user)
          end
        rescue => e
          handle_error(e)
        end

        # GET's the status of a person options transaction from the VAProfile api
        # @param transaction_id [String] the transaction_id to check
        # @return [VAProfile::ContactInformation::V2::PersonOptionsTransactionResponse] wrapper around a tx object
        def get_person_options_transaction_status(transaction_id)
          # Delegate to PersonSettings service for the actual API call (different endpoint)
          person_settings_service = VAProfile::PersonSettings::Service.new(@user)

          with_monitoring do
            raw_response = person_settings_service.perform(:get, "person-options/v1/status/#{transaction_id}")
            VAProfile::Stats.increment_transaction_results(raw_response, 'person_options')

            # Return a ContactInformation TransactionResponse for consistency
            VAProfile::ContactInformation::V2::PersonOptionsTransactionResponse.from(raw_response)
          end
        rescue => e
          handle_error(e)
        end

        private

        def verify_vet360_id!
          return if @user&.vet360_id.present?

          raise Common::Exceptions::RecordNotFound.new(
            @user&.uuid,
            detail: 'User does not have a VA Profile ID'
          )
        end

        def verify_user!
          unless @user&.vet360_id.present? || @user&.icn.present?
            raise 'ContactInformationV2 - Missing User ICN and VAProfile_ID'
          end

          Rails.logger.info("ContactInformationV2 User MVI Verified? : #{@user&.icn.present?},
            VAProfile Verified? #{@user&.vet360_id.present?}")
        end

        def vet360_aaid
          "#{@user.vet360_id}^PI^200VETS^USDVA"
        end

        def vaprofile_aaid
          return vet360_aaid if @user.vet360_id.present?

          "#{@user.icn}^NI^200M^USVHA" # AAID for VAProfile Requests ONLY
        end

        def update_model(model, attr, method_name)
          contact_info = VAProfileRedis::V2::ContactInformation.for_user(@user)
          model.id = contact_info.public_send(attr)&.id
          verb = model.id.present? ? 'put' : 'post'

          public_send("#{verb}_#{method_name}", model)
        end

        def get_email_personalisation(type)
          { 'contact_info' => EMAIL_PERSONALISATIONS[type] }
        end

        def send_contact_change_notification(transaction_status, personalisation)
          transaction = transaction_status.transaction

          if transaction.completed_success?
            transaction_id = transaction.id
            return if TransactionNotification.find(transaction_id).present?

            email = @user.va_profile_email
            return if email.blank?

            VANotifyEmailJob.perform_async(
              email,
              CONTACT_INFO_CHANGE_TEMPLATE,
              get_email_personalisation(personalisation)
            )

            TransactionNotification.create(transaction_id:)
          end
        end

        def send_email_change_notification(transaction_status)
          transaction = transaction_status.transaction

          if transaction.completed_success?
            old_email = OldEmail.find(transaction.id)
            return if old_email.nil?

            personalisation = get_email_personalisation(:email)

            VANotifyEmailJob.perform_async(old_email.email, CONTACT_INFO_CHANGE_TEMPLATE, personalisation)
            if transaction_status.new_email.present?
              VANotifyEmailJob.perform_async(
                transaction_status.new_email,
                CONTACT_INFO_CHANGE_TEMPLATE,
                personalisation
              )
            end

            old_email.destroy
          end
        end

        def post_or_put_data(method, model, path, response_class)
          with_monitoring do
            verify_user!
            request_path = "#{MPI::Constants::VA_ROOT_OID}/#{ERB::Util.url_encode(vaprofile_aaid)}" + "/#{path}"
            raw_response = perform(method, request_path, model.in_json)
            response_class.from(raw_response)
          end
        rescue => e
          handle_error(e)
        end

        def get_transaction_status(path, response_class)
          with_monitoring do
            raw_response = perform(:get, path)
            VAProfile::Stats.increment_transaction_results(raw_response)

            response_class.from(raw_response)
          end
        rescue => e
          handle_error(e)
        end
      end
    end
  end
end
