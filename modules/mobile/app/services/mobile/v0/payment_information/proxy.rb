# frozen_string_literal: true

module Mobile
  module V0
    module PaymentInformation
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

        def send_confirmation_email(ga_client_id)
          if Flipper.enabled?(:direct_deposit_vanotify, @user)
            VANotifyDdEmailJob.send_to_emails(@user.all_emails, :comp_pen)
          else
            DirectDepositEmailJob.send_to_emails(@user.all_emails, ga_client_id, :comp_pen)
          end
        end

        private

        def service
          @service ||= EVSS::PPIU::Service.new(@user)
        end
      end
    end
  end
end
