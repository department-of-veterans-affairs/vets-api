# frozen_string_literal: true

module IHub
  module Appointments
    class Service < Common::Client::Base
      include Common::Client::Monitoring

      configuration IHub::Appointments::Configuration

      STATSD_KEY_PREFIX = 'api.ihub'

      def initialize(user)
        @user = user
      end

      def appointments
        return nil if @user.icn.blank?

        with_monitoring do
          response = perform(:get, @user.icn, nil)
          IHub::Appointments::Response.from(response)
        end
      rescue StandardError => error
        log_message_to_sentry(error.message, :error, extra_context: { url: config.base_path })
        raise error
      end
    end
  end
end
