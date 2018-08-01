# frozen_string_literal: true

require 'common/models/redis_store'
require 'common/models/concerns/cache_aside'

class EVSSClaimsRedisHelper < Common::RedisStore
  include Common::CacheAside

  redis_config_key :evss_claims_store

  attr_reader :user_uuid
  attr_accessor :claim_id

  def initialize(attributes, persisted = false)
    @user_uuid = attributes[:user_uuid]
    @claim_id = attributes[:claim_id]
    super
  end

  def find_collection
    self.class.find(collection_key)
  end

  def find_one
    self.class.find(single_record_key)
  end

  def cache_collection(content_hash)
    cache(collection_key, content_hash)
  end

  def cache_one(content_hash)
    cache(single_record_key, content_hash)
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
    unless claim_id
      raise Common::Exceptions::InternalServerError, ArgumentError.new(
        'EVSSClaimsRedisHelper#single_record_key was called without having set a claim_id'
      )
    end
    "#{user_uuid}.update_from_remote.#{claim_id}"
  end
end
