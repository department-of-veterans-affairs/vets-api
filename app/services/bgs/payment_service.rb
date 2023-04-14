# frozen_string_literal: true

module BGS
  class PaymentService
    include SentryLogging

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

      response
    rescue => e
      log_exception_to_sentry(e, { icn: }, { team: Constants::SENTRY_REPORTING_TEAM })
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
  end
end
