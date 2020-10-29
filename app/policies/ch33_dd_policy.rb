# frozen_string_literal: true

Ch33DdPolicy = Struct.new(:user, :ch33_dd) do
  def access?
    Flipper.enabled?(:ch33_dd, user) && user.loa3?
  end
end
