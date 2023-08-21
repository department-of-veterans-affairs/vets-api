# frozen_string_literal: true

EVSSPolicy = Struct.new(:user, :evss) do
  def access?
    if user.edipi.present? && user.ssn.present? && user.participant_id.present?
      log_success('access')
    else
      log_failure('access')
    end
  end

  def access_letters?
    if user.edipi.present? && user.ssn.present? && user.participant_id.present? &&
       user&.vet360_contact_info&.mailing_address&.address_line1
      log_success('letters')
    else
      log_failure('letters')
    end
  end

  def access_form526?
    if user.edipi.present? && user.ssn.present? && user.birls_id.present? && user.participant_id.present? &&
       user.birth_date.present?
      log_success('form526')
    else
      log_failure('form526')
    end
  end

  alias_method :rating_info_access?, :access?

  private

  def log_success(policy)
    StatsD.increment('api.evss.policy.success', tags: ["policy:#{policy}"]) if user.loa3?
    true
  end

  def log_failure(policy)
    StatsD.increment('api.evss.policy.failure', tags: ["policy:#{policy}"]) if user.loa3?
    false
  end
end
