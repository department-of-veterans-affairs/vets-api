# frozen_string_literal: true

module UserAudit
  class Logger < SemanticLogger::Logger
    def initialize
      super('UserAudit', 'info', /UserAudit/)
    end

    UserAction.statuses.each_key do |status|
      define_method(status) do |*args, **kwargs|
        kwargs[:status] = status

        info(*args, **kwargs)
      end
    end
  end
end
