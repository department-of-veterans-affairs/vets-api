# frozen_string_literal: true
module PensionBurial
  class Service < Common::Client::Base
    configuration PensionBurial::Configuration

    def upload(metadata, file_body, mime_type)
      request(
        :post,
        '',
        token:  Settings.pension_burial.upload.token,
        metadata: metadata.to_json,
        document: Faraday::UploadIO.new(
          file_body,
          mime_type
        )
      )
    end
  end
end
