# frozen_string_literal: true

module EVSS
  class LoggedServiceException < EVSS::ServiceException
    def initialize(res_body, user, req_body = nil)
      log_exception(res_body, user, req_body)

      super(res_body)
    end

    private

    def log_exception(res_body, user, req_body)
      # don't need to log GET exceptions, those are already logged to sentry with the response body saved
      return if req_body.blank?

      PersonalInformationLog.create(
        error_class: self.class.to_s,
        data: {
          user: {
            uuid: user.uuid,
            edipi: user.edipi,
            ssn: user.ssn
          },
          request: req_body,
          response: res_body
        }
      )
    end
  end
end
