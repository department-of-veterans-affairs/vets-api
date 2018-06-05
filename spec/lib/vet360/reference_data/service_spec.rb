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
          expect(response.reference_data).to be_present
          expect(response.reference_data['country_list']).to be_an(Array)
        end
      end
    end

    context 'with a 400 response' do
      xit 'raises an exception' do
        VCR.use_cassette('vet360/person/init_vet360_id_status_400', VCR::MATCH_EVERYTHING) do
          expect { subject.init_vet360_id(icn) }.to raise_error do |e|
            expect(e).to be_a(Common::Exceptions::BackendServiceException)
            expect(e.status_code).to eq(400)
            expect(e.errors.first.code).to eq('VET360_PERS101')
          end
        end
      end
    end
  end
end
