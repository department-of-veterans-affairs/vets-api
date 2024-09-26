# frozen_string_literal: true

require 'common/models/redis_store'

module Form1010cg
  class SubmissionJobClaim < Common::RedisStore
    redis_store REDIS_CONFIG[:form_1010_cg_submission_job_claim][:namespace]
    redis_ttl REDIS_CONFIG[:form_1010_cg_submission_job_claim][:each_ttl]
    redis_key :claim_id

    attribute :claim_id
    validates :claim_id, presence: true

    def self.set_claim_key(claim_id)
      redis_namespace.set(claim_id, 't') unless redis_namespace.exists?(claim_id)
    end
  end
end
