# frozen_string_literal: true

DGIPolicy = Struct.new(:user, :dgi) do
  def access?
    user.icn.present? && user.ssn.present?
  end
end
