class GiBillFeedback < Common::RedisStore
  include SetGuid
  include TempFormValidation

  attr_accessor(:user)

  FORM_ID = 'complaint-tool'

  redis_config_key(:gi_bill_feedback)
  redis_key(:guid)

  attribute(:state)
  attribute(:guid)
  attribute(:response)

  validates(:state, presence: true, inclusion: %w[success failed pending])
  validates(:response, presence: true, if: :success?)

  def success?
    state == 'success'
  end
end
