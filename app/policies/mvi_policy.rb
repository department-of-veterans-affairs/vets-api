# frozen_string_literal: true

MVIPolicy = Struct.new(:user, :mvi) do
  def access?
    user.ssn.present? || user.icn.present?
  end
end
