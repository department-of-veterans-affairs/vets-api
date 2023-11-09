# frozen_string_literal: true

HCADisabilityRatingPolicy = Struct.new(:user, :hca_disability_rating) do
  def access?
    user.loa3? && user.ssn.present?
  end
end
