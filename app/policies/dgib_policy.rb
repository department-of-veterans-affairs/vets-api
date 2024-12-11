# frozen_string_literal: true

DGIBPolicy = Struct.new(:user, :dgib) do
  def access?
    user.icn.present? && user.ssn.present?
  end
end
