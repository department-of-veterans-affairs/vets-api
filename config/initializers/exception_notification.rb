# frozen_string_literal: true
require 'exception_notification/rails'
require 'exception_notification/sidekiq'

ExceptionNotification.configure do |config|
  config.add_notifier :slack, webhook_url: ENV['EXCEPTIONS_SLACK_WEBHOOK'],
                              channel: '#exceptions',
                              backtrace_lines: 10,
                              additional_parameters: {
                                mrkdwn: true
                              }
end
