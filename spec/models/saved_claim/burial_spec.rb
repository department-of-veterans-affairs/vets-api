# frozen_string_literal: true

require 'rails_helper'
require 'lib/saved_claims_spec_helper'

RSpec.describe SavedClaim::Burial do
  subject { described_class.new }

  let(:instance) { FactoryBot.build(:burial_claim) }

  it_behaves_like 'saved_claim_with_confirmation_number'

  describe '#email' do
    it 'returns the users email' do
      expect(instance.email).to eq('foo@foo.com')
    end
  end
end
