# frozen_string_literal: true
module PensionBurial
  class Service < Common::Client::Base
    configuration PensionBurial::Configuration

    def upload(metadata, file)
      request(
        :post,
        '',
        token:  Settings.pension_burial.upload.token,
        metadata: metadata.to_json,
        document: Faraday::UploadIO.new(
          file.read,
          file.mime_type
        )
      )
    end
  end
end
