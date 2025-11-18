# frozen_string_literal: true

require 'bgs/monitor'

module BGS
  class PaymentService
    attr_reader :common_name, :email, :icn

    def initialize(user)
      @common_name = user.common_name
      @email = user.email
      @icn = user.icn
    end

    def payment_history(person)
      response = service.payment_information.retrieve_payment_summary_with_bdn(
        person.participant_id,
        person.file_number,
        '00', # payee code
        person.ssn_number
      )
      return empty_response if response[:payments].nil?

      payments = Array.wrap(response[:payments][:payment])
      exclude_third_party_payments(payments)
      recategorize_hardship(payments)

      response
    rescue => e
      monitor.error(e.message, 'payment_history_error')
      empty_response if e.message.include?('No Data Found')
    end

    private

    def service
      @service ||= BGS::Services.new(external_uid: icn, external_key:)
    end

    def external_key
      @external_key ||= begin
        key = common_name.presence || email
        key.first(Constants::EXTERNAL_KEY_MAX_LENGTH)
      end
    end

    def empty_response
      { payments: { payment: [] } }
    end

    def exclude_third_party_payments(payments)
      payments.select! do |pay|
        pay[:payee_type] != 'Third Party/Vendor' && pay[:beneficiary_participant_id] == pay[:recipient_participant_id]
      end
    end

    def recategorize_hardship(payments)
      payments.each do |payment|
        if payment[:payee_type] == 'Veteran' &&
           payment[:program_type] == 'Chapter 33' &&
           payment[:payment_type].match(/Hardship/)
          payment[:payment_type] = "CH 33 #{payment[:payment_type]}"
        end
      end
    end

    def monitor
      @monitor ||= BGS::Monitor.new
    end
  end
end
