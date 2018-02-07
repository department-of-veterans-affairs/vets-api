# frozen_string_literal: true

MHVPolicy = Struct.new(:user, :mhv) do
  def account_eligible?
    (MhvAccount::ALL_STATES - [:ineligible]).map(&:to_s).include?(user.mhv_account_state)
  end
end
