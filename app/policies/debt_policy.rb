# frozen_string_literal: true

DebtPolicy = Struct.new(:user, :debt) do
  def access?
    user.icn.present? && user.ssn.present?
  end
end
