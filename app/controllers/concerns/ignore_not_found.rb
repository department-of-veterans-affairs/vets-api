# frozen_string_literal: true

module IgnoreNotFound
  def skip_sentry_exception_types
    Raven.configure { |c| c.excluded_exceptions += 'Common::Exceptions::RecordNotFound' }
  end
end
