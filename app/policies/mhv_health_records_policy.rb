# frozen_string_literal: true

MhvHealthRecordsPolicy = Struct.new(:user, :mhv_health_records) do
  ACCOUNT_TYPES = %w[Premium Advanced Basic].freeze

  def access?
    ACCOUNT_TYPES.include?(user.mhv_account_type)
  end
end
