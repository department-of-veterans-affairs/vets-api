# frozen_string_literal: true

class EVSSClaimsSyncStatusTracker < Common::RedisStore
  redis_store REDIS_CONFIG[:evss_claims_store][:namespace]
  redis_ttl REDIS_CONFIG[:evss_claims_store][:each_ttl]
  redis_key :user_uuid

  attribute :user_uuid, String
  attribute :status_hash, Hash
  attr_accessor :claim_id

  def get_collection_status
    status_hash[collection_key]
  end

  def get_single_status
    status_hash[single_record_key]
  end

  def set_collection_status(status)
    status_hash[collection_key] = status
    save
  end

  def set_single_status(status)
    status_hash[single_record_key] = status
    save
  end

  def delete_collection_status
    status_hash.delete(collection_key)
    save
  end

  def delete_single_status
    status_hash.delete(single_record_key)
    save
  end

  private

  def collection_key
    unless user_uuid
      raise Common::Exceptions::InternalServerError, ArgumentError.new(
        'EVSSClaimsRedisHelper#collection_key was called without having set a user uuid'
      )
    end
    'all'
  end

  def single_record_key
    arr = []
    arr << 'claim_id' unless claim_id
    arr << 'user_uuid' unless user_uuid

    unless arr.empty?
      raise Common::Exceptions::InternalServerError, ArgumentError.new(
        "EVSSClaimsRedisHelper#single_record_key was called without having set a #{arr.join(', ')}"
      )
    end
    "update_from_remote.#{claim_id}"
  end
end
