# frozen_string_literal: true

require 'common/models/redis_store'
require 'common/models/concerns/cache_aside'

class EVSSClaimsSyncStatusTracker < Common::RedisStore
  include Common::CacheAside

  redis_config_key :evss_claims_store

  attr_reader :user_uuid
  attr_accessor :claim_id

  def initialize(attributes, persisted = false)
    @user_uuid = attributes[:user_uuid]
    @claim_id = attributes[:claim_id]
    super
  end

  def get_collection_status
    self.class.find(collection_key)
  end

  def get_single_status
    self.class.find(single_record_key)
  end

  def set_collection_status(status)
    cache(collection_key, status: status)
  end

  def set_single_status(status)
    cache(single_record_key, status: status)
  end

  private

  def collection_key
    unless user_uuid
      raise Common::Exceptions::InternalServerError, ArgumentError.new(
        'EVSSClaimsRedisHelper#collection_key was called without having set a user uuid'
      )
    end
    "#{user_uuid}.all"
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
    "#{user_uuid}.update_from_remote.#{claim_id}"
  end
end
