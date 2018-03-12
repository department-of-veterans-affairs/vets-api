# frozen_string_literal: true

MHVACPolicy = Struct.new(:user, :mhv_ac) do

  def access?
    user.loa3? && user.va_patient?
  end

  def creatable?
    eligible? &&  user.mhv_account.creatable?
  end

  def upgradable?
    eligible? && user.mhv_account.upgradable?
  end
end
