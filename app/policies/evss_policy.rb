# frozen_string_literal: true

EVSSPolicy = Struct.new(:user, :evss) do
  def access?
    user.edipi.present? && user.ssn.present? && user.participant_id.present?
  end
end
