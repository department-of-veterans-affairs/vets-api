# frozen_string_literal: true

require 'rx/client'

MHVPrescriptionsPolicy = Struct.new(:user, :mhv_prescriptions) do
  def access?
    user.loa3? && (mhv_user_account&.patient || mhv_user_account&.champ_va)
  end

  private

  def mhv_user_account
    user.mhv_user_account(from_cache_only: false)
  end
end
