# frozen_string_literal: true

require 'common/models/redis_store'

##
# Models an ineligible MHV Account
#
#  @!attribute uuid
#    @return [String]
#  @!attribute account_state
#    @return [String]
#  @!attribute mhv_correlation_id
#    @return [String]
#  @!attribute tracker_id
#    @return [String]
#  @!attribute icn
#    @return [String]
#
class MHVAccountIneligible < Common::RedisStore
  redis_store REDIS_CONFIG[:mhv_account_ineligible][:namespace]
  redis_ttl REDIS_CONFIG[:mhv_account_ineligible][:each_ttl]
  redis_key :tracker_id

  attribute :uuid
  attribute :account_state
  attribute :mhv_correlation_id
  attribute :tracker_id
  attribute :icn

  validates :uuid, presence: true
end
