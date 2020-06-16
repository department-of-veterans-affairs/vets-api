# frozen_string_literal: true

module RedisForm
  extend ActiveSupport::Concern

  included do |base|
    # i tried to make this module a class but it didn't work because of how RedisStore was defined
    raise 'must be a subclass of Common::RedisStore' unless base < Common::RedisStore

    include SetGuid
    include AsyncRequest

    attr_accessor(:user)
    attr_accessor(:form)

    redis_store(name.underscore)
    redis_ttl(86_400)
    redis_key(:guid)

    attribute(:state, String, default: 'pending')
    attribute(:guid, String)
    attribute(:response, String)

    alias_method :id, :guid

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
