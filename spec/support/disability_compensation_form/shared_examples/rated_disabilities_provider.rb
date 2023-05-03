# frozen_string_literal: true

require 'rails_helper'

shared_examples 'rated disabilities provider' do
  # this is used to instantiate any RateDisabilitiesProvider with a current_user
  subject do
    described_class.new(
      {
        auth_headers: EVSS::DisabilityCompensationAuthHeaders
                        .new(current_user)
                        .add_headers(EVSS::AuthHeaders.new(current_user).to_h),
        icn: ''
      }
    )
  end

  it { is_expected.to respond_to(:get_rated_disabilities) }
end
