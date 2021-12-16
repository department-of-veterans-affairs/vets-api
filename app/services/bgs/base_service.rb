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
      external_key = @user.common_name || @user.email

      if external_key.length > 39
        external_key = external_key[0, 39]

        # this is temp logging
        if @user.common_name.present? && @user.common_name.length > 39
          log_message_to_sentry('common name greater than 39', :info, {}, { team: 'vfs-ebenefits' })
        elsif @user.email.present? && @user.email.length > 39
          log_message_to_sentry('email greater than 39', :info, {}, { team: 'vfs-ebenefits' })
        end
      end

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
  end
end
