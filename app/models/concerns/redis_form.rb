module RedisForm
  extend ActiveSupport::Concern

  included do
    include SetGuid
    include AsyncRequest

    attr_accessor(:user)
    attr_accessor(:form)

    name.underscore.tap do |class_name|
      redis_store REDIS_CONFIG[class_name]['namespace']
      redis_ttl REDIS_CONFIG[class_name]['each_ttl']
    end

    redis_key(:guid)

    attribute(:state, String, default: 'pending')
    attribute(:guid, String)
    attribute(:response, String)

    alias id guid

    validate(:form_matches_schema, unless: :persisted?)
    validates(:form, presence: true, unless: :persisted?)
  end

  def parsed_form
    @parsed_form ||= JSON.parse(form)
  end

  def parsed_response
    return if response.blank?
    @parsed_response ||= JSON.parse(response)
  end

  def save
    originally_persisted = @persisted
    saved = super

    create_submission_job if saved && !originally_persisted

    saved
  end

  private

  def form_matches_schema
    if form.present?
      errors[:form].concat(JSON::Validator.fully_validate(VetsJsonSchema::SCHEMAS[self.class::FORM_ID], parsed_form))
    end
  end
end
