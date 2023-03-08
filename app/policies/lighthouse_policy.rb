# frozen_string_literal: true

LighthousePolicy = Struct.new(:user, :lighthouse) do
  def access?
    user.icn.present? && user.participant_id.present?
  end
end
