# frozen_string_literal: true

module IHub
  module Appointments
    class Service < IHub::Service
      include Common::Client::Monitoring

      configuration IHub::Appointments::Configuration

      def get
        return nil if @user.icn.blank?

        with_monitoring do
          perform(:get, @user.icn)
        end
      rescue StandardError => error
        log_message_to_sentry(error.message, :error, extra_context: { url: config.base_path })
        raise_backend_exception('VA900', self.class, error)
      end
    end
  end
end
