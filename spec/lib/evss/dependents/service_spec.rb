# frozen_string_literal: true

require 'rails_helper'

describe EVSS::Dependents::Service do
  let(:user) { build(:user, :loa3) }
  subject { described_class.new(user) }

  describe '#retrieve' do
    context 'when successful' do
      it 'returns a status of 200' do
        VCR.use_cassette('evss/dependents/retrieve_user_with_max_attributes') do
          response = subject.retrieve
          expect(response).to be_ok
        end
      end

      it 'returns a users dependents info' do
        VCR.use_cassette('evss/dependents/retrieve_user_with_max_attributes') do
          response = subject.retrieve
          expect(response.attributes.keys).to include :body, :status
          expect(response.attributes[:body].keys).to eq(['submitProcess'])
        end
      end
    end
  end

  describe '#submit' do
    it 'deletes the cached response' do
      VCR.use_cassette('evss/dependents/retrieve_user_with_max_attributes') do
        expect_any_instance_of(EVSS::Dependents::RetrievedInfo).to receive(:delete)
        subject.submit
      end
    end
  end
end
