# frozen_string_literal: true

# RedisStore for caching evidence submission polling to prevent redundant Lighthouse API calls.
# This implements the cache-aside pattern to reduce load on Lighthouse Benefits Documents API.
#
# Cache Strategy:
# - Caches the set of request_ids that have been successfully polled for a given claim
# - TTL of 60 seconds balances freshness with API call reduction
# - Natural invalidation occurs when the set of pending request_ids changes
#
# Usage:
#   # Check cache
#   cache_record = EvidenceSubmissionPollStore.find(claim_id.to_s)
#
#   # Write to cache
#   EvidenceSubmissionPollStore.create(
#     claim_id: claim_id.to_s,
#     request_ids: [123, 456, 789]
#   )
#
# See: https://depo-platform-documentation.scrollhelp.site/developer-docs/how-to-guide-caching-with-redis-namespace-in-vets-
class EvidenceSubmissionPollStore < Common::RedisStore
  redis_store REDIS_CONFIG[:evidence_submission_poll_store][:namespace]
  redis_ttl REDIS_CONFIG[:evidence_submission_poll_store][:each_ttl]
  redis_key :claim_id

  attribute :claim_id, String
  attribute :request_ids, Array[Integer]

  validates :claim_id, :request_ids, presence: true
end
