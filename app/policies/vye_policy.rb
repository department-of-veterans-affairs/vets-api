# frozen_string_literal: true

VyePolicy = Struct.new(:user, :user_info) do
  def access?
    user.present?
  end
end
