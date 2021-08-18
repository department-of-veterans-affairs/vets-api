# frozen_string_literal: true

MedicalCopaysPolicy = Struct.new(:user, :medical_copays) do
  ##
  # Determines if the authenticated user has
  # access to the Medical Copays feature
  #
  # @return [Boolean]
  #
  def access?
    Flipper.enabled?('show_medical_copays', user) && user.edipi.present? && user.icn.present?
  end
end
