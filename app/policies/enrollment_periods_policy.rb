# frozen_string_literal: true

EnrollmentPeriodsPolicy = Struct.new(:user, :enrollment_periods) do
  def access?
    user.present? && user.loa3? && user.icn.present?
  end
end
