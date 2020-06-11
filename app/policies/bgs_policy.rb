# frozen_string_literal: true

# rubocop:disable Metrics/BlockLength

BGSPolicy = Struct.new(:user, :bgs) do
  def access?
    if user.icn.present? && user.ssn.present? && user.participant_id.present?
      log_success
    else
      log_failure
    end
  end

  private

  def log_success
    StatsD.increment('api.bgs.policy.success') if user.loa3?
    true
  end

  def log_failure
    StatsD.increment('api.bgs.policy.failure') if user.loa3?
    false
  end
end
# rubocop:enable Metrics/BlockLength
