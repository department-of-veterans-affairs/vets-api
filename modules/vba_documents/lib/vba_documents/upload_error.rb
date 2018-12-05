# frozen_string_literal: true

module VBADocuments
  class UploadError < StandardError
    attr_accessor :code
    attr_accessor :detail

    # DOC1xx errors: client errors, invalid submissions
    DOC101 = 'Invalid multipart payload'
    DOC102 = 'Invalid metadata part'
    DOC103 = 'Invalid content part'
    DOC104 = 'Upload rejected by downstream system'
    DOC105 = 'Invalid or unknown id'

    # DOC2xx errors: server errors either local or downstream
    # not unambiguously related to submitted content
    DOC201 = 'Upload server error. Request will be retried when upstream service is available.'
    DOC202 = 'Error during processing by downstream system'

    STATSD_UPLOAD_FAIL_KEY = 'api.vba.document_upload.fail'

    def initialize(message = nil, code: nil, detail: nil)
      if message.nil?
        begin
          message = UploadError.const_get code if code.present?
        rescue NameError
          message = 'Internal Server Error'
        end
      end
      super(message)
      @code = code
      @detail = detail

      StatsD.increment STATSD_UPLOAD_FAIL_KEY, tags: ["status:#{code}"]
    end
  end
end
