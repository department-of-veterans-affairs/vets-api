# frozen_string_literal: true

MhvAccountCreationPolicy = Struct.new(:user, :mhv_account_creation) do
  # Note: we could have used creatable? || upgradable?, but want to avoid fetching
  # eligible data classes where possible.
  def access?
    user.mhv_account.may_register? || user.mhv_account.may_upgrade?
  end
end
