# frozen_string_literal: true

Ch33DdPolicy = Struct.new(:user, :ch33_dd) do
  def access?
    user.loa3? && Flipper.enabled?(:direct_deposit_edu, user)
  end
end
