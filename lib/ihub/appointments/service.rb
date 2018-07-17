# frozen_string_literal: true

require 'common/client/base'

module IHub
  module Appointments
    class Service < IHub::Service
      include Common::Client::Monitoring

      configuration IHub::Appointments::Configuration

      def appointments
        return nil if @user.icn.blank?

        with_monitoring do
          response = perform(:get, @user.icn, nil)

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
