# frozen_string_literal: true

require 'common/client/base'

module IHub
  module Appointments
    class Service < IHub::Service
      include Common::Client::Monitoring

      configuration IHub::Appointments::Configuration

      def appointments
        raise 'User has no ICN' if @user.icn.blank?

        with_monitoring do
          service_url = "#{@user.icn}?noFilter=true"
          response    = perform(:get, service_url, nil)

          IHub::Appointments::Response.from(response)
        end
      rescue StandardError => error
        log_message_to_sentry(
          error.message,
          :error,
          extra_context: { url: config.base_path },
          ihub: 'appointments'
        )

        raise error
      end
    end
  end
end
