# frozen_string_literal: true

require 'rails_helper'

describe Vet360::Person::Service, skip_vet360: true do
  before { Timecop.freeze('2018-04-09T17:52:03Z') }
  after  { Timecop.return }

  describe '#init_vet360_id' do
    let(:user) { build(:user_with_suffix, :loa3) }
    subject { described_class.new(user) }

    context 'with a user present, that has a icn_with_aaid, and no passed in ICN' do
      it 'returns a status of 200', :aggregate_failures do
        VCR.use_cassette('vet360/person/init_vet360_id_success', VCR::MATCH_EVERYTHING) do
          response = subject.init_vet360_id

          expect(response).to be_ok
          expect(response).to be_a(Vet360::ContactInformation::PersonTransactionResponse)
        end
      end

      it 'initiates an asynchronous Vet360 transaction', :aggregate_failures do
        VCR.use_cassette('vet360/person/init_vet360_id_success', VCR::MATCH_EVERYTHING) do
          response = subject.init_vet360_id

          expect(response.transaction.id).to be_present
          expect(response.transaction.status).to be_present
        end
      end
    end

    context 'with a passed in ICN' do
      let(:icn) { '1000123456V123456' }
      let(:rake_user) { 'rake_user' }
      subject { described_class.new(rake_user) }

      it 'returns a status of 200', :aggregate_failures do
        VCR.use_cassette('vet360/person/init_vet360_id_success', VCR::MATCH_EVERYTHING) do
          response = subject.init_vet360_id(icn)

          expect(response).to be_ok
          expect(response).to be_a(Vet360::ContactInformation::PersonTransactionResponse)
        end
      end

      it 'initiates an asynchronous Vet360 transaction', :aggregate_failures do
        VCR.use_cassette('vet360/person/init_vet360_id_success', VCR::MATCH_EVERYTHING) do
          response = subject.init_vet360_id(icn)

          expect(response.transaction.id).to be_present
          expect(response.transaction.status).to be_present
        end
      end
    end

    context 'with a 400 response' do
      it 'raises an exception', :aggregate_failures do
        VCR.use_cassette('vet360/person/init_vet360_id_status_400', VCR::MATCH_EVERYTHING) do
          expect { subject.init_vet360_id }.to raise_error do |e|
            expect(e).to be_a(Common::Exceptions::BackendServiceException)
            expect(e.status_code).to eq(400)
            expect(e.errors.first.code).to eq('VET360_PERS101')
          end
        end
      end
    end
  end
end
