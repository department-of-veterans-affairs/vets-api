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
        { json: { reference_number:, status: }, status: lgy_response.status }
      end
    end
  end
end
