# frozen_string_literal: true

require 'common/client/concerns/monitoring'
require 'common/client/errors'
require 'va_profile/service'
require 'va_profile/stats'
require_relative 'configuration'
require_relative 'person_response'
require_relative 'transaction_response'

module VAProfile
  module ProfileInformation
    class Service < Common::Client::Base
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
      configuration VAProfile::ProfileInformation::Configuration

      OID = '2.16.840.1.113883.3.42.10001.100001.12'
      AAID = '^NI^200DOD^USDOD'

      attr_reader :user

      def initialize(user)
        @user = user
        super()
      end

      def get_response(type)
        with_monitoring do
          icn_with_aaid_present!
          model = model(type)
          raw_response = perform(:post, path, { bios: [{ bioPath: model.bio_path }] })
          response = model.response_class(raw_response)
          Sentry.set_extras(response.debug_data) unless response.ok?
          response
        end
      rescue => e
        handle_error(e)
      end

      def self.get_person(vet360_id)
        stub_user = OpenStruct.new(vet360_id:)
        new(stub_user).get_response('person')
      end

      def submit(params)
        config.submit(path(@user.edipi), params)
      end

      # Record is not defined when requesting an #update
      # Determine if the record needs to be created or updated with reassign_http_verb
      # Ensure http_verb is a symbol for the response request
      def create_or_update_info(http_verb, type, record)
        with_monitoring do
          icn_with_aaid_present!
          http_verb = http_verb.to_sym == :update ? reassign_http_verb(type, record) : http_verb.to_sym
          raw_response = perform(http_verb, type.pluralize, record.in_json)
          response = response_class(type).from(raw_response)
          return response unless http_verb == :put && type == 'email' && old_email.present?

          transaction = response.transaction
          return response unless transaction.received?

          # Create OldEmail to send notification to user's previous email
          OldEmail.create(transaction_id: transaction.id, email: old_email)
          response
        end
      rescue => e
        handle_error(e)
      end

      def get_transaction_status(transaction_id, type)
        with_monitoring do
          icn_with_aaid_present!
          transaction_status_path = model(type).transaction_status_path(@user, transaction_id)
          raw_response = perform(:get, transaction_status_path)
          VAProfile::Stats.increment_transaction_results(raw_response)

          transaction_status = response_class(type).from(raw_response)
          return transaction_status unless model(type).send_change_notifcations?

          send_change_notifications(transaction_status)
          transaction_status
        end
      rescue => e
        handle_error(e)
      end

      private

      def model(type)
        "VAProfile::Models::#{type.capitalize}".constantize
      end

      def response_class(type)
        model(type).response_class
      end

      def icn_with_aaid
        return "#{@user.idme_uuid}^PN^200VIDM^USDVA" if @user.idme_uuid
        return "#{@user.logingov_uuid}^PN^200VLGN^USDVA" if @user.logingov_uuid

        nil
      end

      def icn_with_aaid_present!
        raise 'User does not have a icn' if icn_with_aaid.blank?
      end


      def path
        oid = MPI::Constants::VA_ROOT_OID
        "#{oid}/#{ERB::Util.url_encode(icn_with_aaid)}"
      end

      def old_email(transaction_id: nil)
        return @user.va_profile_email if transaction_id.nil?

        OldEmail.find(transaction_id).try(:email)
      end

      # create_or_update cannot determine if record exists
      # Reassign :update to either :put or :post
      def reassign_http_verb(type, record)
        contact_info = VAProfileRedis::ProfileInformation.for_user(@user)
        attr = model(type).contact_info_attr
        raise "invalid #{type} VAProfile::ProfileInformation" if attr.nil?

        record.id = contact_info.public_send(attr)&.id
        record.id.present? ? :put : :post
      end

      def get_email_personalisation(type)
        { 'contact_info' => EMAIL_PERSONALISATIONS[type] }
      end

      def send_change_notifications(transaction_status)
        transaction = transaction_status.transaction
        transaction_id = transaction.id
        return if transaction.completed_success? || TransactionNotification.find(transaction_id).present?

        email_transaction = transaction_status.new_email.present?
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
