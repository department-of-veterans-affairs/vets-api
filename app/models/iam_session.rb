# frozen_string_literal: true

# Subclasses the `Session` model. Adds a unique redis namespace for IAM sessions.
#
class IAMSession < Session
  redis_store REDIS_CONFIG[:iam_session][:namespace]
  redis_ttl REDIS_CONFIG[:iam_session][:each_ttl]
  redis_key :token
end
