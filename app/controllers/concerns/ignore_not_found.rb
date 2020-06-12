# frozen_string_literal: true

module IgnoreNotFound
  def skip_sentry_exception_types
    ApplicationController::SKIP_SENTRY_EXCEPTION_TYPES + [Common::Exceptions::Internal::RecordNotFound]
  end
end
