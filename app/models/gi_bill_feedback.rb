class GiBillFeedback < Common::RedisStore
  include SetGuid
  include TempFormValidation
  include AsyncRequest

  attr_accessor(:user)

  FORM_ID = 'complaint-tool'

  redis_config_key(:gi_bill_feedback)
  redis_key(:guid)

  attribute(:state)
  attribute(:guid)
  attribute(:response)
end
