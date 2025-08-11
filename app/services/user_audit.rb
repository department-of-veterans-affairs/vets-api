# frozen_string_literal: true

module UserAudit
  LOG_FILTER = ->(log) { log.name != 'UserAudit' }
  SemanticLogger.add_appender(appender: Appenders::UserActionAppender.new, filter: LOG_FILTER)
  SemanticLogger.add_appender(appender: Appenders::AuditLogAppender.new, filter: LOG_FILTER)

  def self.logger
    @logger ||= Logger.new # rubocop:disable ThreadSafety/ClassInstanceVariable
  end
end
