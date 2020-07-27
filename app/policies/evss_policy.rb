# frozen_string_literal: true

# rubocop:disable Metrics/BlockLength
EVSSPolicy = Struct.new(:user, :evss) do
  def access?
    evss_attrs? ? log_success : log_failure
  end

  def access_form526?
    form526_attrs? ? log_success : log_failure
  end

  def access_original_claims?
    user_attrs? && (user.birls_id.blank? || user.participant_id.blank?) ? log_success : log_failure
  end

  private

  def user_attrs?
    user.edipi.present? && user.ssn.present?
  end

  def evss_attrs?
    user_attrs? && user.participant_id.present?
  end

  def form526_attrs?
    user.birls_id.present? && evss_attrs?
  end

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
