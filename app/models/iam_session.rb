# frozen_string_literal: true

class IAMSession < Session
  redis_store REDIS_CONFIG[:iam_session][:namespace]
  redis_ttl REDIS_CONFIG[:iam_session][:each_ttl]
end
