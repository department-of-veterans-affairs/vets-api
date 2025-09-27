# frozen_string_literal: true

VAProfilePolicy = Struct.new(:user, :va_profile) do
  def access?
    user.edipi.present?
  end

  def access_to_v2?
    user.icn.present?
  end
end
