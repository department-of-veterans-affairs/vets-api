# frozen_string_literal: true

VAOSPolicy = Struct.new(:user, :vaos) do
  def access?
    user.loa3?
  end
end
