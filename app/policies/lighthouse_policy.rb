# frozen_string_literal: true

LighthousePolicy = Struct.new(:user, :lighthouse) do
  def access_claims?
    user.icn.present? && user.participant_id.present?
  end
end
