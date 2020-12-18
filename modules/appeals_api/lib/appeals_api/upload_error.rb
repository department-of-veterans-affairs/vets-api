# frozen_string_literal: true

require 'central_mail/upload_error'

module AppealsApi
  class UploadError < CentralMail::UploadError
    STATSD_UPLOAD_FAIL_KEY = 'api.appeals.document_upload.fail'
  end
end
