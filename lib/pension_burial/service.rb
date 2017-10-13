# frozen_string_literal: true
module PensionBurial
  class Service < Common::Client::Base
    include Common::Client::FileUpload
    configuration PensionBurial::Configuration

    def upload
      request(
        :post,
        '',
        token:  Settings.pension_burial.upload.token,
        metadata: {
          filename: 'foo.pdf'
        }.to_json,
        document: get_upload_io_object('spec/fixtures/pdf_fill/extras.pdf')
      )
    end
  end
end
