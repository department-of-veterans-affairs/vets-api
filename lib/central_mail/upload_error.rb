# frozen_string_literal: true

require 'pdf_utilities/pdf_validator'
require 'central_mail/upload_error'

module CentralMail
  class UploadError < StandardError
    attr_accessor :code, :detail

    DEFAULT_MESSAGE = 'Internal Server Error'

    # DOC1xx errors: client errors, invalid submissions
    DOC101 = 'Invalid multipart payload'
    DOC102 = 'Invalid metadata part'
    DOC103 = 'Invalid content part'
    DOC104 = 'Upload rejected by upstream system'
    DOC105 = 'Invalid or unknown id'
    DOC106 = 'Maximum document size exceeded.'
    DOC107 = 'Empty payload'
    DOC108 = 'Maximum page size exceeded.'

    # DOC2xx errors: server errors either local or upstream
    # not unambiguously related to submitted content
    DOC201 = 'Upload server error. Request will be retried when upstream service is available.'
    DOC202 = 'Error during processing by upstream system'

    STATSD_UPLOAD_FAIL_KEY = 'api.central_mail.upload.fail'

    def self.extra_message_text(code, pdf_validator_options)
      opts = PDFUtilities::PDFValidator::Validator::DEFAULT_OPTIONS.merge(pdf_validator_options.to_h)

      case code.to_s
      when 'DOC106'
        "Limit is #{PDFUtilities.formatted_file_size(opts[:size_limit_in_bytes])} per document."
      when 'DOC108'
        "Limit is #{opts[:width_limit_in_inches]} in x #{opts[:height_limit_in_inches]} in."
      else
        ''
      end
    end

    def initialize(message = nil, code: nil, detail: nil, pdf_validator_options: {})
      if message.nil? && code.present?
        begin
          message = UploadError.const_get code.to_sym
          extra = UploadError.extra_message_text(code, pdf_validator_options)
          message += " #{extra}" if extra.present?
        rescue NameError
          message = DEFAULT_MESSAGE
        end
      end
      super(message || DEFAULT_MESSAGE)
      @code = code
      @detail = detail

      StatsD.increment self.class::STATSD_UPLOAD_FAIL_KEY, tags: ["status:#{code}"]
    end
  end
end
