# frozen_string_literal: true

require 'medical_records/user_eligibility/client'

MHVMedicalRecordsPolicy = Struct.new(:user, :mhv_medical_records) do
  MR_ACCOUNT_TYPES = %w[Premium].freeze

  def access?
    if Flipper.enabled?(:mhv_medical_records_new_eligibility_check)
      user.loa3? && (mhv_user_account&.patient || mhv_user_account&.champ_va)
    else
      MR_ACCOUNT_TYPES.include?(user.mhv_account_type) && user.va_patient?
    end
  end

  private

  def mhv_user_account
    user.mhv_user_account(from_cache_only: false)
  end
end
