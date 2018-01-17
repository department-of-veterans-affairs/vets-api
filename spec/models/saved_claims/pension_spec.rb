# frozen_string_literal: true

require 'rails_helper'
require 'lib/saved_claims_spec_helper'

RSpec.describe SavedClaim::Pension do
  subject { described_class.new }
  let(:instance) { FactoryBot.build(:pension_claim) }

  it_should_behave_like 'saved_claim_with_confirmation_number'

  describe '#email' do
    it 'should return the users email' do
      expect(instance.email).to eq('foo@foo.com')
    end
  end
end
