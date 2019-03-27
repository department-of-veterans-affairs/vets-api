# frozen_string_literal: true

Form526Policy = Struct.new(:user, :form526) do
  def access?
    if all_attrs?
      StatsD.increment('api.evss.policy.success') if user.loa3?
      true
    else
      StatsD.increment('api.evss.policy.failure') if user.loa3?
      false
    end
  end

  def all_attrs?
    user.edipi.present? && user.ssn.present? && user.participant_id.present? && user.birls_id.present?
  end
end
