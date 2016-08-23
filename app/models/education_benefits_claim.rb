class EducationBenefitsClaim < RedisStore
  attribute :submitted_at
  attribute :json
  attribute :processed_at
  attribute :uuid
  alias redis_key uuid

  before_validation(:generate_uuid)

  validates(:uuid, presence: true)

  private

  def generate_uuid
    self.uuid ||= "#{self.class.to_s.underscore}:#{SecureRandom.uuid}"
  end
end
