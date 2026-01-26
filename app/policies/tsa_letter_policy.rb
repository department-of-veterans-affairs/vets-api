# frozen_string_literal: true

TsaLetterPolicy = Struct.new(:user, :tsa_letter) do
  def access?
    user.present? && user.icn.present?
  end
end
