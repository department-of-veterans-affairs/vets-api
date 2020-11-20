class PreferredFacility < ApplicationRecord
  attr_accessor :user
  belongs_to :account, inverse_of: :preferred_facilities

  validates(:account, :facility_code, presence: true)
  validates(:user, presence: true, on: :create)
  validate(:facility_code_included_in_user_list, on: :create)

  before_validation(:set_account, on: :create)

  private

  def set_account
    self.account = user.account if account.blank? && user.present?
  end

  def facility_code_included_in_user_list
    return true if user.blank?

    unless user.va_treatment_facility_ids.include?(facility_code)
      errors[:facility_code] << "must be included in user's va treatment facilities list"
    end
  end
end
