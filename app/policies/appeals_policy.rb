# frozen_string_literal: true

AppealsPolicy = Struct.new(:user, :appeals) do
  def access?
    user.loa3? && user.ssn.present?
  end
end
