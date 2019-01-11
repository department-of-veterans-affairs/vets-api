Rails.application.configure do
 puts "REMINDER: you have development_local loaded"
   # Use the lowest log level to ensure availability of diagnostic information
  # when problems arise.
  config.log_level = :info

  config.log_tags = {
    request_id: :uuid,
    session: proc do |session|
      Session.obscure_token(session[:token])
    end,
    ref: ->(_request) { AppInfo::GIT_REVISION },
    consumer_id: ->(request) { request.headers['X-Consumer-ID'] },
    consumer_username: ->(request) { request.headers['X-Consumer-Username'] },
    consumer_custom_id: ->(request) { request.headers['X-Consumer-Custom-ID'] },
    credential_username: ->(request) { request.headers['X-Credential-Username'] }
  }

  config.rails_semantic_logger.format = :json
  config.rails_semantic_logger.add_file_appender = false
  config.semantic_logger.add_appender(io: STDOUT,
                                      level: config.log_level,
                                      formatter: config.rails_semantic_logger.format)

  config.semantic_logger.application = if Sidekiq.server?
                                         'vets-api-worker'
                                       else
                                         'vets-api-server'
                                       end


  # Use default logging formatter so that PID and timestamp are not suppressed.
  config.log_formatter = ::Logger::Formatter.new

  # Log to standard out, with specified formatter
  # STDOUT.sync = config.autoflush_log
  logger = ActiveSupport::Logger.new(STDOUT)
  logger.formatter = config.log_formatter
  config.logger = ActiveSupport::TaggedLogging.new(logger)
end