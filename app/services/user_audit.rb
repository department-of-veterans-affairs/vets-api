# frozen_string_literal: true

module UserAudit
  def self.logger
    @logger ||= begin
      SemanticLogger.add_appender(appender: Appender.new, filter: /UserAudit/)
      Logger.new
    end
  end
end
