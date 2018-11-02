# frozen_string_literal: true

require 'rails_helper'

describe EVSS::Dependents::RetrievedInfo do
  let(:user) { build(:user, :loa3) }

  subject { described_class.for_user(user) }

  describe '#body' do
    it 'returns the response body' do
      VCR.use_cassette('evss/dependents/retrieve_user_with_max_attributes') do
        expect(subject.body).to be_a(Hash)
        expect(subject.body.keys).to eq(['submitProcess'])
      end
    end

    it 'caches the result' do
      VCR.use_cassette('evss/dependents/retrieve_user_with_max_attributes') do
        expect_any_instance_of(EVSS::Dependents::Service).to receive(:retrieve).once.and_call_original
        subject.body
        subject.body
      end
    end
  end
end
