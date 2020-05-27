# frozen_string_literal: true

# rubocop:disable Metrics/BlockLength

EVSSPolicy = Struct.new(:user, :evss) do
  def access?
    if user.edipi.present? && user.ssn.present? && user.participant_id.present?
      log_success
    else
      log_failure
    end
  end

  def access_original_claims?
    if user.edipi.present? && user.ssn.present? && (user.birls_id.blank? || user.participant_id.blank?)
      log_success
    else
      log_failure
    end
  end

  def access_form526?
    if user.edipi.present? && user.ssn.present? && user.birls_id.present? && user.participant_id.present?
      log_success
    else
      log_failure
    end
  end

  private

  def log_success
    StatsD.increment('api.evss.policy.success') if user.loa3?
    true
  end

  def log_failure
    StatsD.increment('api.evss.policy.failure') if user.loa3?
    false
  end
end
# rubocop:enable Metrics/BlockLength
