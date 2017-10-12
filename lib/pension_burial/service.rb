# frozen_string_literal: true
module PensionBurial
  class Service < Common::Client::Base
    include Common::Client::FileUpload
    configuration PensionBurial::Configuration

    def upload
      binding.pry; fail
      request(
        :post,
        '',
        token: YAML.load_file('config/application.yml')['TOKEN'],
        metadata: {
          filename: 'foo.pdf'
        }.to_json,
        document: get_upload_io_object('spec/fixtures/pdf_fill/extras.pdf')
      )
    end
  end
end
