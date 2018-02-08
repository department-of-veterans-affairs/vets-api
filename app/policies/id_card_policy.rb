# frozen_string_literal: true

IdCardPolicy = Struct.new(:user, :id_card) do
  def access?
    user.loa3? && user.edipi.present? &&
      ID_CARD_ALLOWED_STATUSES.include?(user.veteran_status.title38_status)
  rescue StandardError # Default to false for any veteran_status error
    false
  end
end
