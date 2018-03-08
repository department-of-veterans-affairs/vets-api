# frozen_string_literal: true

module PensionBurial
  class Service < Common::Client::Base
    configuration PensionBurial::Configuration

    # rubocop:disable Metrics/MethodLength
    def upload(body)
      body['token'] = Settings.pension_burial.upload.token

      response = request(
        :post,
        '',
        body
      )
      # TODO: remove logging after confirming that pension burial uploads are working in staging
      if Rails.env.production?
        log_message_to_sentry(
          'pension burial api upload',
          :info,
          {
            response: {
              status: response.status,
              body: response.body
            }
          }
        )
      end

      response
    end
    # rubocop:enable Metrics/MethodLength
  end
end
