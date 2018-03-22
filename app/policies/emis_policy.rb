# frozen_string_literal: true

EMISPolicy = Struct.new(:user, :emis) do
  def access?
    user.edipi.present? || user.icn.present?
  end
end
