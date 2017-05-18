class MhvAccount < ActiveRecord::Base
  include AASM

  has_many :terms_and_conditions_acceptances, foreign_key: :user_uuid, primary_key: :user_uuid
  has_many :advanced_account_terms, -> { where(terms_and_conditions: { latest: true, name: 'mhv_advanced_account_terms' }) },
                                   through: :terms_and_conditions_acceptances,
                                   source: :terms_and_conditions,
                                   foreign_key: :user_uuid,
                                   primary_key: :user_uuid

  has_many :premium_account_terms, -> { where(terms_and_conditions: { latest: true, name: 'mhv_premium_account_terms' }) },
                                  through: :terms_and_conditions_acceptances,
                                  source: :terms_and_conditions,
                                  foreign_key: :user_uuid,
                                  primary_key: :user_uuid

  aasm(:account_state) do
    # TODO
  end


  def terms_and_conditions_accepted?
    advanced_account_terms.any? && premium_account_terms.any?
  end


  private

  def user
    @user ||= User.find(user_uuid)
  end

  def va_patient?
    user.icn.present?
  end

  def has_account?
    ['registered', 'upgraded'].include?(account_state) || user.mhv_correlation_id.present?
  end

  def emis_veteran_state
    # TODO: this will invoke the emis client and be used to determine if is_veteran
  end
end
