# frozen_string_literal: true

# The VeteranOnboarding model represents the onboarding status of a veteran.
# Each instance corresponds to a veteran who is in the process of onboarding.
#
# == Schema Information
#
# Table name: veteran_onboardings
#
#  id                      :bigint           not null, primary key
#  user_account_uuid       :string           not null, unique
#  display_onboarding_flow :boolean          default(TRUE)
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#
class VeteranOnboarding < ApplicationRecord
  belongs_to :user_account, primary_key: :id, foreign_key: :user_account_uuid, inverse_of: :veteran_onboarding
  validates :user_account, uniqueness: true

  attr_accessor :user

  # Determines whether the onboarding flow should be displayed for a veteran.
  # Currently, we have two feature toggle checks:
  # - veteran_onboarding_show_to_newly_onboarded examines settings for veteran_onboarding.onboarding_threshold_days,
  #   (default 180 days) and examines the user_verification.verified_at attribute
  # - veteran_onboarding_beta_flow just checks if the feature toggle is enabled for the user
  def show_onboarding_flow_on_login
    if @user.user_account&.verified?
      if Flipper.enabled?(:veteran_onboarding_show_to_newly_onboarded, @user)
        days_since_verification = UserVerification.where(user_account_id: @user.user_account_uuid).map do |uv|
          (Time.zone.today - uv.verified_at.to_date).to_i
        end.max
        threshold_days = Settings.veteran_onboarding&.onboarding_threshold_days || 180
        if days_since_verification <= threshold_days
          display_onboarding_flow
        else
          update!(display_onboarding_flow: false)
          false
        end
      elsif Flipper.enabled?(:veteran_onboarding_beta_flow, @user)
        display_onboarding_flow
      end
    end
  end

  def self.for_user(user)
    if user.user_account&.verified? && (
      Flipper.enabled?(:veteran_onboarding_beta_flow, user) ||
      Flipper.enabled?(:veteran_onboarding_show_to_newly_onboarded, user)
    )
      veteran_onboarding = find_or_create_by(user_account: user.user_account)
      veteran_onboarding.user = user
      veteran_onboarding
    end
  end
end
