# frozen_string_literal: true

MhvAccountCreationPolicy = Struct.new(:user, :mhv_account_creation) do
  def access?
    user.mhv_account.creatable? || user.mhv_account.upgradable?
  end
end
