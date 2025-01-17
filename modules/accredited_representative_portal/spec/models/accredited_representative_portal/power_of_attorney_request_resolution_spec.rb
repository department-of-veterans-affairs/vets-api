# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AccreditedRepresentativePortal::PowerOfAttorneyRequestResolution, type: :model do
  it 'must uniquely be associated to a poa request' do
    poa_request = create(:power_of_attorney_request, skip_resolution: true)
    resolution_a = create(:power_of_attorney_request_resolution, :expiration,
                        power_of_attorney_request: poa_request)

    resolution_b = build(
      :power_of_attorney_request_resolution, :expiration,
      power_of_attorney_request: resolution_a.power_of_attorney_request
    )

    expect(resolution_b).not_to be_valid
    expect(resolution_b.errors.full_messages).to eq(
      [
        'Power of attorney request has already been taken'
      ]
    )
  end
end
