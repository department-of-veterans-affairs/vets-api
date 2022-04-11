# frozen_string_literal: true

require 'rails_helper'

RSpec.describe VANotify::Veteran, type: :model do
  describe '#initialize' do
    it 'instantiates a claims veteran' do
      allow(ClaimsApi::Veteran).to receive(:new)
      VANotify::Veteran.new(
        ssn: '012345678',
        first_name: 'Melvin',
        last_name: 'AlsoMelvin',
        birth_date: Time.zone.now.iso8601
      )

      expect(ClaimsApi::Veteran).to have_received(:new)
    end
  end
end
