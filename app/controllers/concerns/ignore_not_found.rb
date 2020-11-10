# frozen_string_literal: true

module IgnoreNotFound
  def skip_sentry_exception?(exception)
    return true if exception.is_a?(Common::Exceptions::RecordNotFound)
    super(exception)
  end
end
