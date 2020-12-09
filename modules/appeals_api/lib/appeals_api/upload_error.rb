# frozen_string_literal: true

require 'central_mail/upload_error'

module AppealsApi
  class UploadError < CentralMail::UploadError
    # TODO: how does this work?
    STATSD_UPLOAD_FAIL_KEY = 'api.appeals.higher_level_review_upload.fail'
  end
end
