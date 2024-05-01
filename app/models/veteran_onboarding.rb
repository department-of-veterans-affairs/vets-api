# frozen_string_literal: true

# The VeteranOnboarding model represents the onboarding status of a veteran.
# Each instance corresponds to a veteran who is in the process of onboarding.
#
# == Schema Information
#
# Table name: veteran_onboardings
#
#  id                      :bigint           not null, primary key
#  icn                     :string          not null, unique
#  display_onboarding_flow :boolean          default(TRUE)
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#
class VeteranOnboarding < ApplicationRecord
  # Ensures that ICN is present and unique for each veteran onboarding record
  validates :icn, presence: true, uniqueness: true

  # Determines whether the onboarding flow should be displayed for a veteran.
  # Currently, this is based solely on the value of the `display_onboarding_flow` attribute.
  # In the future, additional information (like MPI info) might be taken into account.
  def show_onboarding_flow_on_login
    display_onboarding_flow
  end
end
