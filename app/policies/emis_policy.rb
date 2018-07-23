# frozen_string_literal: true

EMISPolicy = Struct.new(:user, :emis) do
  def access?
    user.edipi.present?
  end
end
