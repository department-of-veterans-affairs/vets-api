# frozen_string_literal: true

PPIUPolicy = Struct.new(:user, :ppiu) do
  def access?
    user.loa3? && user.multifactor
  end
end
