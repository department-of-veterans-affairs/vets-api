class EducationBenefitsClaim < RedisStore
  attribute :submitted_at, Time
  attribute :json, String
  attribute :processed_at, Time
  attribute :uuid, String
  alias redis_key uuid

  after_initialize(:generate_uuid)
  after_initialize(:set_submitted_at)

  validates(:uuid, :json, :submitted_at, presence: true)

  private

  def set_submitted_at
    self.submitted_at ||= Time.zone.now
  end

  def generate_uuid
    self.uuid ||= "#{self.class.to_s.underscore}:#{SecureRandom.uuid}"
  end
end
