# frozen_string_literal: true

require 'rx/client'

MHVPrescriptionsPolicy = Struct.new(:user, :mhv_prescriptions) do
  RX_ACCOUNT_TYPES = %w[Premium Advanced].freeze

  def access?
    user.loa3? && (mhv_user_account&.patient || mhv_user_account&.champ_va)
  end

  private

  def mhv_user_account
    user.mhv_user_account(from_cache_only: false)
  end
end
