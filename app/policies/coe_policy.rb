# frozen_string_literal: true

CoePolicy = Struct.new(:user, :coe) do
  def access?
    user.loa3? && user.edipi.present?
  end
end
