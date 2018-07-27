class GIBillFeedback < Common::RedisStore
  include SetGuid
  include AsyncRequest

  attr_accessor(:user)
  attr_accessor(:form)

  FORM_ID = 'complaint-tool'

  redis_store REDIS_CONFIG['gi_bill_feedback']['namespace']
  redis_ttl REDIS_CONFIG['gi_bill_feedback']['each_ttl']
  redis_key(:guid)

  attribute(:state, String, default: 'pending')
  attribute(:guid, String)
  attribute(:response, String)

  alias_method(:id, :guid)

  validate(:form_matches_schema, unless: :persisted?)
  validates(:form, presence: true, unless: :persisted?)

  def parsed_form
    @parsed_form ||= JSON.parse(form)
  end

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

  def form_matches_schema
    if form.present?
      errors[:form].concat(JSON::Validator.fully_validate(VetsJsonSchema::SCHEMAS[self.class::FORM_ID], parsed_form))
    end
  end

  def create_submission_job
    puts 'soubmission job'
    # binding.pry; fail
    # SubmissionJob.perform_async(id, form, user&.uuid)
  end
end
