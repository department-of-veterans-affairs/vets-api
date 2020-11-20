class PreferredFacility < ApplicationRecord
  attr_accessor :user
  belongs_to :account, inverse_of: :preferred_facilities

  validates(:account, :facility_code, presence: true)
  validates(:user, presence: true, on: :create)
  validate(:facility_code_included_in_user_list, on: :create)

  before_validation(:set_account, on: :create)

  private

  def set_account
    self.account = user.account if account.blank?
  end

  def facility_code_included_in_user_list
  end
end
