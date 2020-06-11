# frozen_string_literal: true

# rubocop:disable Metrics/BlockLength

MviPolicy = Struct.new(:user, :mvi) do
  def missing_critical_ids?
    if user.edipi.present? && user.ssn.present? && (user.birls_id.blank? || user.participant_id.blank?)
      log_success
    else
      log_failure
    end
  end

  def queryable?
    user.icn.present? || required_attrs_present?(user)
  end

  private

  def log_failure
    StatsD.increment('api.mvi.policy.failure') if user.loa3?
    false
  end

  def log_success
    StatsD.increment('api.mvi.policy.success') if user.loa3?
    true
  end

  def required_attrs_present?(user)
    return false if user.first_name.blank?
    return false if user.last_name.blank?
    return false if user.birth_date.blank?
    return false if user.ssn.blank?
    return false if user.gender.blank?

    true
  end
end
# rubocop:enable Metrics/BlockLength
