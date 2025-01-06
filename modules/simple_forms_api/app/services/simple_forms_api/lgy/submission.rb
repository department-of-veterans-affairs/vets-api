# frozen_string_literal: true

require 'lgy/service'

module SimpleFormsApi
  module LGY
    class Submission
      LGY_API_FORMS = %w[26-4555].freeze

      def initialize(current_user, params)
        @current_user = current_user
        @params = params
      end

      def submit
        parsed_form_data = JSON.parse(params.to_json)
        form = SimpleFormsApi::VBA264555.new(parsed_form_data)
        lgy_response = LGY::Service.new.post_grant_application(payload: form.as_payload)
        reference_number = lgy_response.body['reference_number']
        status = lgy_response.body['status']
        Rails.logger.info(
          'Simple forms api - sent to lgy',
          { form_number: params[:form_number], status:, reference_number: }
        )

        handle_emails(status, parsed_form_data, reference_number) if Flipper.enabled?(:simple_forms_email_confirmations)

        { json: { reference_number:, status: }, status: lgy_response.status }
      end

      private

      def handle_emails(status, parsed_form_data, reference_number)
        case status
        when 'VALIDATED', 'ACCEPTED'
          send_sahsha_email(parsed_form_data, reference_number, :confirmation)
        when 'REJECTED'
          send_sahsha_email(parsed_form_data, reference_number, :rejected)
        when 'DUPLICATE'
          send_sahsha_email(parsed_form_data, reference_number, :duplicate)
        end
      end

      def send_sahsha_email(parsed_form_data, confirmation_number, notification_type)
        config = {
          form_data: parsed_form_data,
          form_number: 'vba_26_4555',
          confirmation_number:,
          date_submitted: Time.zone.today.strftime('%B %d, %Y')
        }
        notification_email = SimpleFormsApi::NotificationEmail.new(
          config,
          notification_type:,
          user: @current_user
        )
        notification_email.send
      end
    end
  end
end
