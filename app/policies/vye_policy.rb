# frozen_string_literal: true

VyePolicy = Struct.new(:user, :user_info) do
  def access?
    return true if user.present?

    false
  end

  alias_method :claimant_lookup?, :access?
end
