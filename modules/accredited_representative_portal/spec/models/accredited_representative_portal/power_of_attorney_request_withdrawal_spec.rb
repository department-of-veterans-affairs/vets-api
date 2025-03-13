# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AccreditedRepresentativePortal::PowerOfAttorneyRequestWithdrawal, type: :model do
  it 'validates inclusion of type in (replacement)' do
    withdrawal = build(:power_of_attorney_request_withdrawal, type: 'invalid')
    withdrawal.valid?

    expect(withdrawal).not_to be_valid
    expect(withdrawal.errors.full_messages).to eq(
      [
        'Type is not included in the list'
      ]
    )
  end
end
