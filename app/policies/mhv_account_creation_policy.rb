# frozen_string_literal: true

MhvAccountCreationPolicy = Struct.new(:user, :mhv_account_creation) do
  def access?
    user.loa3? && user.va_patient?
  end

  def creatable?
    eligible? && user.mhv_correlation_id.empty?
  end

  def upgradable?
    eligible? && user.mhv_correlation_id.present? && user.mhv_account.registered_at? && !user.mhv_account.upgraded_at?
  end
end
