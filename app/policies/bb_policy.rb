# frozen_string_literal: true

BBPolicy = Struct.new(:user, :mhv_health_records) do
  ACCOUNT_TYPES = %w[Premium Advanced Basic]

  def access?
    ACCOUNT_TYPES.include?(user.mhv_account_type)
  end
end
