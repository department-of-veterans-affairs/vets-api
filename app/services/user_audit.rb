# frozen_string_literal: true

module UserAudit
  LOG_FILTER = ->(log) { log.name != 'UserAudit' }

  def self.logger
    @logger ||= begin # rubocop:disable ThreadSafety/ClassInstanceVariable
      SemanticLogger.add_appender(appender: Appenders::UserActionAppender.new, filter: LOG_FILTER)
      SemanticLogger.add_appender(appender: Appenders::AuditLogAppender.new, filter: LOG_FILTER)

      Logger.new
    end
  end
end
