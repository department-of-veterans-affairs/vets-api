# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AccreditedRepresentativePortal::PowerOfAttorneyRequestDecision, type: :model do
  it 'validates inclusion of type in (acceptance, declination)' do
    decision = build(:power_of_attorney_request_decision, type: 'invalid')
    decision.valid?

    expect(decision).not_to be_valid
    expect(decision.errors.full_messages).to eq(
      [
        'Type is not included in the list'
      ]
    )
  end
end
