# frozen_string_literal: true

module BGS
  class PaymentService
    include SentryLogging

    def initialize(current_user)
      @current_user = current_user
    end

    def payment_history
      # rubocop:disable Rails/DynamicFindBy
      response = service.payment_history.find_by_ssn(@current_user.ssn)
      # rubocop:enable Rails/DynamicFindBy

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
