# frozen_string_literal: true

PowerOfAttorneyPolicy = Struct.new(:user, :power_of_attorney) do
  def access?
    user.loa3? && user.icn.present? && user.participant_id.present?
  end
end
