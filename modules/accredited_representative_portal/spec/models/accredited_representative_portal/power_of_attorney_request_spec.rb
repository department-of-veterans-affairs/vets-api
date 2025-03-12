# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AccreditedRepresentativePortal::PowerOfAttorneyRequest, type: :model do
  it 'validates its form and claimant type' do
    poa_request =
      build(
        :power_of_attorney_request,
        power_of_attorney_form: build(
          :power_of_attorney_form,
          data: {}.to_json
        ),
        power_of_attorney_holder_type: 'abc'
      )

    expect(poa_request).not_to be_valid
    expect(poa_request.errors.full_messages).to contain_exactly(
      'Claimant type is not included in the list',
      'Power of attorney holder type is not included in the list',
      'Power of attorney form data does not comply with schema'
    )
  end
end
