# frozen_string_literal: true

MhvHealthRecordsPolicy = Struct.new(:user, :mhv_health_records) do
  BB_ACCOUNT_TYPES = %w[Premium Advanced Basic].freeze

  def access?
    BB_ACCOUNT_TYPES.include?(user.mhv_account_type)
  end
end
