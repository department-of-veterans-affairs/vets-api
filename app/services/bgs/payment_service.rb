# frozen_string_literal: true

module BGS
  class PaymentService
    include SentryLogging

    def initialize(current_user)
      @current_user = current_user
    end

    def payment_history
      response = service.payment_history.find_by(ssn: @current_user.ssn)

      response[:payment_record]
    rescue => e
      return { payment_address: [], payments: [], return_payments: [] } if e.message.include?('No payment record found')

      report_error(e)
    end

    private

    def report_error(e)
      log_exception_to_sentry(
        e,
        {
          icn: @current_user.icn
        },
        { team: 'vfs-ebenefits' }
      )

      PersonalInformationLog.create(
        error_class: e,
        data: {
          user: {
            uuid: @current_user.uuid,
            edipi: @current_user.edipi,
            ssn: @current_user.ssn,
            participant_id: @current_user.participant_id
          }
        }
      )
    end

    def service
      external_key = @current_user.common_name || @current_user.email

      @service ||= BGS::Services.new(
        external_uid: @current_user.icn,
        external_key: external_key
      )
    end
  end
end
