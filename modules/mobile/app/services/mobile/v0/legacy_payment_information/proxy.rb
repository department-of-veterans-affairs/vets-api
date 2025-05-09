# frozen_string_literal: true

module Mobile
  module V0
    module LegacyPaymentInformation
      class Proxy
        include SentryLogging

        def initialize(user)
          @user = user
        end

        def get_payment_information
          service.get_payment_information.responses[0]
        end

        def update_payment_information(pay_info)
          service.update_payment_information(pay_info).responses[0]
        end

        def send_confirmation_email
          VANotifyDdEmailJob.send_to_emails(@user.all_emails)
        end

        private

        def service
          @service ||= EVSS::PPIU::Service.new(@user)
        end
      end
    end
  end
end
