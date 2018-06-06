# frozen_string_literal: true

require 'rails_helper'

describe Vet360::ReferenceData::Service, skip_vet360: true do
  let(:user) { build(:user, :loa3) }
  subject { described_class.new(user) }

  before { Timecop.freeze('2018-04-09T17:52:03Z') }
  after  { Timecop.return }

  describe '#countries' do
    context 'when successful' do
      it 'returns a status of 200', :aggregate_failures do
        VCR.use_cassette('vet360/reference_data/countries', VCR::MATCH_EVERYTHING) do
          response = subject.countries

          expect(response).to be_ok
          expect(response.reference_data).to be_a(Hash)
        end
      end
    end
  end

  describe '#states' do
    context 'when successful' do
      it 'returns a status of 200', :aggregate_failures do
        VCR.use_cassette('vet360/reference_data/states', VCR::MATCH_EVERYTHING) do
          response = subject.states

          expect(response).to be_ok
          expect(response.reference_data).to be_a(Hash)
        end
      end
    end
  end

  describe '#zipcodes' do
    context 'when successful' do
      it 'returns a status of 200', :aggregate_failures do
        VCR.use_cassette('vet360/reference_data/zipcodes', VCR::MATCH_EVERYTHING) do
          response = subject.zipcodes

          expect(response).to be_ok
          expect(response.reference_data).to be_a(Hash)
        end
      end
    end
  end
end
