# frozen_string_literal: true

module BGS
  class PaymentService
    include SentryLogging
    class NoPaymentHistory < StandardError; end
    class NoReturnedPaymentHistory < StandardError; end

    def initialize(current_user)
      @current_user = current_user
    end

    def payment_history
      response = service.payment_history.find_by_ssn(@current_user.ssn)
      payments = response.dig(:payment_record, :payments)
      returned_payments = response.dig(:payment_record, :return_payments)


      raise NoPaymentHistory if payments.nil?
      raise NoReturnedPaymentHistory if returned_payments.nil?
      binding.pry
      { payments: payments, returned_payments: returned_payments }
    rescue NoPaymentHistory => e
      report_no_payment_history(e)

      []
    end

    private

    def report_no_payment_history(e)
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
