# frozen_string_literal: true

DebtLettersPolicy = Struct.new(:user, :debt_letters) do
  def access?
    Flipper.enabled?(:debt_letters_show_letters_vbms, user)
  end
end
