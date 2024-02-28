# frozen_string_literal: true

MHVHealthRecordsPolicy = Struct.new(:user, :mhv_health_records) do
  MR_ACCOUNT_TYPES = %w[Premium].freeze

  def access?
    MR_ACCOUNT_TYPES.include?(user.mhv_account_type) && user.va_patient?
  end
end
