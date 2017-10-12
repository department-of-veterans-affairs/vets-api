# frozen_string_literal: true
module PensionBurial
  class Service < Common::Client::Base
    def upload
      post(
        '',
        token: YAML.load_file('config/application.yml')['TOKEN'],
        metadata: {
          filename: 'foo.pdf'
        },
        document: get_upload_io_object('spec/fixtures/pdf_fill/extras.pdf')
      )
      binding.pry; fail
    end
  end
end
