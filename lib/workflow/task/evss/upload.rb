# frozen_string_literal: true
require 'workflow/task/shrine_file/base'

module Workflow::Task::EVSS
  class Upload < Workflow::Task::ShrineFile::Base
    def run(_options = {})
      document = ::EVSSClaimDocument.new data[:document]
      client = ::EVSS::DocumentsService.new(data[:auth_headers].deep_stringify_keys)
      file_body = file.read
      document.file_name = file.original_filename
      client.upload(file_body, document)
    end
  end
end
