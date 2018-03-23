# frozen_string_literal: true

MviPolicy = Struct.new(:user, :mvi) do
  def access?
    user.ssn.present? || user.icn.present?
  end
end
