# frozen_string_literal: true

module Vye; end

Vye::UserInfoPolicy = Struct.new(:user, :user_info) do
  def create?
    return true if user_info.present?

    raise Pundit::NotAuthorizedError
  end
end
