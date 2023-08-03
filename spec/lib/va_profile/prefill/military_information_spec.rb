# frozen_string_literal: true

require 'rails_helper'
require 'vaprofile/prefill/military_information'

describe VAProfile::Prefill::MilitaryInformation do
  let(:military_information) { described_class.new(user) }

  let(:user) { build(:user, :loa3) }
  let(:edipi) { '384759483' }

  before do
    allow(user).to receive(:edipi).and_return(edipi)
  end
  # obviously not going to pass. Just messing around.
  describe 'service_branches' do
    it 'returns the branches of military' do
      expect(military_information.service_branches).to eq(2)
    end
  end
end