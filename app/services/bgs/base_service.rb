# frozen_string_literal: true

module BGS
  class BaseService
    include SentryLogging

    def initialize(user)
      @user = user
      @service = initialize_service
    end

    private

    def initialize_service
      BGS::Services.new(
        external_uid: @user.icn,
        external_key: external_key
      )
    end

    def report_error(error)
      log_exception_to_sentry(
        error,
        {
          icn: @user.icn
        },
        { team: 'vfs-ebenefits' }
      )
    end

    def external_key
      key = @user.common_name.presence || @user.email

      raise Errors::MissingExternalKeyError if key.blank?

      key.first(39)
    end
  end
end
