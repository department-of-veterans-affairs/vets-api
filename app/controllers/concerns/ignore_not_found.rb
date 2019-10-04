# frozen_string_literal: true

module IgnoreNotFound
  def skip_sentry_exception_types
    ErrorHandler::SKIP_SENTRY_EXCEPTION_TYPES + [Common::Exceptions::RecordNotFound]
  end
end
