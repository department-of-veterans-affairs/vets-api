# frozen_string_literal: true

module PensionBurial
  class Service < Common::Client::Base
    configuration PensionBurial::Configuration

    # rubocop:disable Metrics/MethodLength
    def upload(metadata, file_io, mime_type)
      response = request(
        :post,
        '',
        token: Settings.pension_burial.upload.token,
        metadata: metadata.to_json,
        document: Faraday::UploadIO.new(
          file_io,
          mime_type
        )
      )
      # TODO: remove logging after confirming that pension burial uploads are working in staging
      log_message_to_sentry(
        'pension burial api upload',
        :info,
        {
          metadata: metadata,
          response: {
            status: response.status,
            body: response.body
          }
        },
        backend_service: :pension_burial
      )

      response
    end
    # rubocop:enable Metrics/MethodLength
  end
end
