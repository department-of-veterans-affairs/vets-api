class GIBillFeedback < Common::RedisStore
  include SetGuid
  include TempFormValidation
  include AsyncRequest

  attr_accessor(:user)

  FORM_ID = 'complaint-tool'

  redis_store REDIS_CONFIG['gi_bill_feedback']['namespace']
  redis_ttl REDIS_CONFIG['gi_bill_feedback']['each_ttl']
  redis_key(:guid)

  # TODO set these
  attribute(:state)
  attribute(:guid)
  attribute(:response)

  def transform_form
  end

  def save
    originally_persisted = @persisted
    saved = super

    if saved && !originally_persisted
      create_submission_job
    end

    saved
  end

  private

  def create_submission_job
    puts 'soubmission job'
    # binding.pry; fail
    # SubmissionJob.perform_async(id, form, user&.uuid)
  end
end
