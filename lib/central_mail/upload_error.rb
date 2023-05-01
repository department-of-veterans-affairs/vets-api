# frozen_string_literal: true

require 'central_mail/upload_error'

module CentralMail
  class UploadError < StandardError
    attr_accessor :code, :detail

    # DOC1xx errors: client errors, invalid submissions
    DOC101 = 'Invalid multipart payload'
    DOC102 = 'Invalid metadata part'
    DOC103 = 'Invalid content part'
    DOC104 = 'Upload rejected by upstream system'
    DOC105 = 'Invalid or unknown id'
    DOC106 = 'Maximum document size exceeded. Limit is 100MB per document'
    DOC107 = 'Empty payload'
    DOC108 = 'Maximum page size exceeded. Limit is 21 in x 21 in.'

    # DOC2xx errors: server errors either local or upstream
    # not unambiguously related to submitted content
    DOC201 = 'Upload server error. Request will be retried when upstream service is available.'
    DOC202 = 'Error during processing by upstream system'

    STATSD_UPLOAD_FAIL_KEY = 'api.central_mail.upload.fail'

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

      StatsD.increment self.class::STATSD_UPLOAD_FAIL_KEY, tags: ["status:#{code}"]
    end
  end
end
