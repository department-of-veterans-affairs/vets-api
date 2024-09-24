# frozen_string_literal: true

VAOSPolicy = Struct.new(:user, :vaos) do
  def access?
    Flipper.enabled?('va_online_scheduling', user) && user.loa3?
  end

  def facilities_access?
    user.va_patient?
  end
end
