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
          user_emails = @user.all_emails

          if user_emails.present?
            user_emails.each do |email|
              DirectDepositEmailJob.perform_async(email, ga_client_id)
            end
          else
            log_message_to_sentry(
              'Direct Deposit info update: no email address present for confirmation email',
              :info,
              {},
              feature: 'direct_deposit'
            )
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
