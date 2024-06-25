# frozen_string_literal: true

require 'common/client/concerns/monitoring'
require 'common/client/errors'
require 'va_profile/service'
require 'va_profile/stats'
require_relative 'configuration'
require_relative 'transaction_response'

module VAProfile
  module ContactInformation
    class Service < VAProfile::Service
      CONTACT_INFO_CHANGE_TEMPLATE = Settings.vanotify.services.va_gov.template_id.contact_info_change
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

      configuration VAProfile::ContactInformation::Configuration

      # GET's a Person bio from the VAProfile API
      # If a user is not found in VAProfile, an empty PersonResponse with a 404 status will be returned
      # @return [VAProfile::ContactInformation::PersonResponse] response wrapper around an person object
      def get_person
        with_monitoring do
          vet360_id_present!
          raw_response = perform(:get, @user.vet360_id)

          PersonResponse.from(raw_response)
        end
      rescue Common::Client::Errors::ClientError => e
        if e.status == 404
          log_exception_to_sentry(
            e,
            { vet360_id: @user.vet360_id },
            { va_profile: :person_not_found },
            :warning
          )

          return PersonResponse.new(404, person: nil)
        elsif e.status >= 400 && e.status < 500
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






      # def get_person_transaction_status(transaction_id)
      #   with_monitoring do
      #     raw_response = perform(:get, "status/#{transaction_id}")
      #     VAProfile::Stats.increment_transaction_results(raw_response, 'init_vet360_id')

      #     VAProfile::ContactInformation::PersonTransactionResponse.from(raw_response, @user)
      #   end
      # rescue => e
      #   handle_error(e)
      # end



      private

      def get_email_personalisation(type)
        { 'contact_info' => EMAIL_PERSONALISATIONS[type] }
      end

      def send_contact_change_notification(transaction_status, personalisation)
        return unless Flipper.enabled?(:contact_info_change_email, @user)

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
        return unless Flipper.enabled?(:contact_info_change_email, @user)

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



      def get_transaction_status(path, response_class)
        with_monitoring do
          vet360_id_present!
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
