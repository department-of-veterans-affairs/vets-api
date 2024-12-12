# frozen_string_literal: true

DGIPolicy = Struct.new(:user, :dgi) do
  def access?
    user.loa3? && user.icn.present? && user.ssn.present?
  end
end
