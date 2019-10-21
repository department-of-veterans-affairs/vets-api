# frozen_string_literal: true

EVSSPolicy = Struct.new(:user, :evss) do
  def access?
    evss_attrs? ? log_success : log_failure
  end

  def access_form526?
    form526_attrs? ? log_success : log_failure
  end

  private

  def evss_attrs?
    user.present? && user.edipi.present? && user.ssn.present? && user.participant_id.present?
  end

  def form526_attrs?
    evss_attrs? && user.birls_id.present?
  end

  def log_success
    StatsD.increment('api.evss.policy.success') if user.present? && user.loa3?
    true
  end

  def log_failure
    StatsD.increment('api.evss.policy.failure') if user.present? && user.loa3?
    false
  end
end
