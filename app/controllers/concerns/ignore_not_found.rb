# frozen_string_literal: true

module IgnoreNotFound
  def skip_sentry_exception_types
    super + [Common::Exceptions::RecordNotFound]
  end
end
