# frozen_string_literal: true

module PensionBurial
  class Service < Common::Client::Base
    configuration PensionBurial::Configuration

    def upload(body)
      Raven.extra_context(
        request: {
          metadata: body['metadata']
        }
      )
      body['token'] = Settings.pension_burial.upload.token

      response = request(
        :post,
        'upload',
        body
      )
      Raven.extra_context(
        response: {
          status: response.status,
          body: response.body
        }
      )
      # TODO: remove logging after confirming that pension burial uploads are working in staging
      if Rails.env.production?
        log_message_to_sentry(
          'pension burial api upload',
          :info
        )
      end

      response
    end

    def status(uuid_or_list)
      body = {
        'token': Settings.pension_burial.upload.token,
        'uuid': [*uuid_or_list].to_json
      }

      response = request(
        :post,
        'getStatus',
        body
      )

      if Rails.env.production?
        log_message_to_sentry(
          'pension burial api status',
          :info,
          response: {
            status: response.status,
            body: response.body
          }
        )
      end

      response
    end
  end
end
