# frozen_string_literal: true

# Result class for Danger checks.
# Used to return success, warning, or error results from checkers.
# Note: Not wrapped in VSPDanger module to allow standalone usage in tests.
class Result
  ERROR = :error
  WARNING = :warning
  SUCCESS = :success

  attr_reader :severity, :message

  def initialize(severity, message)
    @severity = severity
    @message = message
  end

  def self.error(message)
    Result.new(ERROR, message)
  end

  def self.warn(message)
    Result.new(WARNING, message)
  end

  def self.success(message)
    Result.new(SUCCESS, message)
  end
end
