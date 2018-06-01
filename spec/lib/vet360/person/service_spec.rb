# frozen_string_literal: true

require 'rails_helper'

describe Vet360::Person::Service, skip_vet360: true do
  let(:user) { 'rake_user' }
  let(:icn)  { '1012852978V019884' }
  subject    { described_class.new(user) }

  before { Timecop.freeze('2018-04-09T17:52:03Z') }
  after  { Timecop.return }

  describe '#init_vet360_id' do
    context 'when successful' do
      it 'returns a status of 200', :aggregate_failures do
        VCR.use_cassette('vet360/person/init_vet360_id_success', VCR::MATCH_EVERYTHING) do
          response = subject.init_vet360_id(icn)

          expect(response).to be_ok
          expect(response.person).to be_a(Vet360::Models::Person)
        end
      end

      it 'initializes a vet360_id' do
        VCR.use_cassette('vet360/person/init_vet360_id_success', VCR::MATCH_EVERYTHING) do
          response = subject.init_vet360_id(icn)

          expect(response.person.vet360_id).to eq '323'
        end
      end
    end

    context 'with a 400 response' do
      it 'raises an exception' do
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
