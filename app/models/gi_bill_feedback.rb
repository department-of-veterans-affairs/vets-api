class GiBillFeedback < Common::RedisStore
  include SetGuid
  include TempFormValidation
  include AsyncRequest

  attr_accessor(:user)

  FORM_ID = 'complaint-tool'

  redis_store REDIS_CONFIG['gi_bill_feedback']['namespace']
  redis_ttl REDIS_CONFIG['gi_bill_feedback']['each_ttl']
  redis_key(:guid)

  attr_accessor(:state)
  attr_accessor(:guid)
  attr_accessor(:response)
  define_attribute_methods(:state, :guid, :response)
end
