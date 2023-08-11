# frozen_string_literal: true

require 'rails_helper'
require 'va_profile/prefill/military_information'

describe VAProfile::Prefill::MilitaryInformation do
  subject { described_class.new(user) }
  let(:user) { build(:user, :loa3) }
  let(:edipi) { '384759483' }

  before do
    allow(user).to receive(:edipi).and_return(edipi)
  end

  describe '#last_service_branch' do
    it 'returns the most recent branch of military the veteran served under' do
      VCR.use_cassette('va_profile/military_personnel/post_read_service_history_200') do
        response = subject.last_service_branch

        expect(response).to eq("Army")
      end
    end
  end
end