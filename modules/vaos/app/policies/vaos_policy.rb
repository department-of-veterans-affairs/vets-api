# frozen_string_literal: true

VAOSPolicy = Struct.new(:user, :vaos) do
  def access?
    user.loa3?
  end

  def facilities_access?
    user.va_patient?
  end
end
