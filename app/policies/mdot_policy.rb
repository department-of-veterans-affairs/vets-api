# frozen_string_literal: true

MDOTPolicy = Struct.new(:user, :mdot) do
  def access?
    user.loa3? && user.ssn.present?
  end
end
