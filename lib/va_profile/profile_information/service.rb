# frozen_string_literal: true

require 'common/client/concerns/monitoring'
require 'common/client/errors'
require 'va_profile/service'
require 'va_profile/stats'
require_relative 'configuration'
require_relative 'transaction_response'
require_relative 'person_response'

module VAProfile
  module ProfileInformation
    class Service < VAProfile::Service
      include Common::Client::Concerns::Monitoring

      STATSD_KEY_PREFIX = "#{VAProfile::Service::STATSD_KEY_PREFIX}.profile_information".freeze
      configuration VAProfile::ProfileInformation::Configuration

      OID = MPI::Constants::VA_ROOT_OID
      AAID = '^NI^200DOD^USDOD'

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

      def submit(params)
        config.submit(path(@user.edipi), params)
      end

      # Ensure http_verb is a symbol for the response request
      def create_or_update_info(http_verb, record)
        with_monitoring do
          icn_with_aaid_present!
          http_verb = http_verb.to_sym
          update_path = record.try(:permission_type).present? ? 'permissions' : record.contact_info_attr.pluralize
          raw_response = perform(http_verb, update_path, record.in_json)

          response = record.transaction_response_class.from(raw_response)

          return response unless http_verb == :put && record.contact_info_attr == 'email' && old_email.present?

          transaction = response.transaction
          return response unless transaction.received?

          # Create OldEmail to send notification to user's previous email
          OldEmail.create(transaction_id: transaction.id, email: old_email)
        end
      rescue => e
        handle_error(e)
      end

      def get_transaction_status(transaction_id, model)
        with_monitoring do
          icn_with_aaid_present!
          raw_response = perform(:get, model.transaction_status_path(@user, transaction_id))
          VAProfile::Stats.increment_transaction_results(raw_response)
          transaction_status = model.transaction_response_class.from(raw_response, @user)
          return transaction_status unless model.send_change_notifcations?

          send_change_notifications(transaction_status)
          return response
        end
      rescue => e
        handle_error(e)
      end

      private

      def icn_with_aaid
        return "#{@user.idme_uuid}^PN^200VIDM^USDVA" if @user.idme_uuid
        return "#{@user.logingov_uuid}^PN^200VLGN^USDVA" if @user.logingov_uuid

        nil
      end

      def icn_with_aaid_present!
        raise 'User does not have a icn' if icn_with_aaid.blank?
      end

      def vet360_id_present!
        raise 'User does not have a vet360_id' if @user&.vet360_id.blank?
      end

      def path
        "#{OID}/#{ERB::Util.url_encode(icn_with_aaid)}"
      end

      def old_email(transaction_id: nil)
        return @user.va_profile_email if transaction_id.nil?

        OldEmail.find(transaction_id).try(:email)
      end

      # create_or_update cannot determine if record exists
      # Reassign :update to either :put or :post

      def get_email_personalisation(type)
        { 'contact_info' => EMAIL_PERSONALISATIONS[type] }
      end

      def send_change_notifications(transaction_status)
        transaction = transaction_status.transaction
        transaction_id = transaction.id
        return if !transaction.completed_success? || TransactionNotification.find(transaction_id).present?
        email_transaction = transaction_status.try(:new_email).present?
        notify_email = email_transaction ? old_email(transaction_id) : old_email
        return if notify_email.nil?

        personalisation = transaction_status.changed_field
        notify_email_job(notify_email, personalisation)
        TransactionNotification.create(transaction_id:)
        return unless email_transaction

        # Send notification to new email
        notify_email_job(transaction_status.new_email, personalisation)
        OldEmail.find(transaction_id).destroy
      end

      def notify_email_job(notify_email, personalisation)
        VANotifyEmailJob.perform_async(notify_email, CONTACT_INFO_CHANGE_TEMPLATE,
                                       get_email_personalisation(personalisation))
      end
    end
  end
end
