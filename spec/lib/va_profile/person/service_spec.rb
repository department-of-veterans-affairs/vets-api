# frozen_string_literal: true

require 'rails_helper'
require 'va_profile/person/service'

describe VAProfile::Person::Service, skip_vet360: true do
  before { Timecop.freeze('2018-04-09T17:52:03Z') }

  after  { Timecop.return }

  describe '#init_vet360_id' do
    subject { described_class.new(user) }

    let(:user) { build(:user, :loa3) }

    context 'with a user present, that has a icn_with_aaid, and no passed in ICN' do
      it 'returns a status of 200', :aggregate_failures do
        VCR.use_cassette('va_profile/person/init_vet360_id_success', VCR::MATCH_EVERYTHING) do
          response = subject.init_vet360_id

          expect(response).to be_ok
          expect(response).to be_a(VAProfile::ContactInformation::PersonTransactionResponse)
        end
      end

      it 'initiates an asynchronous VAProfile transaction', :aggregate_failures do
        VCR.use_cassette('va_profile/person/init_vet360_id_success', VCR::MATCH_EVERYTHING) do
          response = subject.init_vet360_id

          expect(response.transaction.id).to be_present
          expect(response.transaction.status).to be_present
        end
      end
    end

    context 'with a passed in ICN' do
      let(:icn) { '1000123456V123456' }

      it 'returns a status of 200', :aggregate_failures do
        VCR.use_cassette('va_profile/person/init_vet360_id_success', VCR::MATCH_EVERYTHING) do
          response = subject.init_vet360_id(icn)

          expect(response).to be_ok
          expect(response).to be_a(VAProfile::ContactInformation::PersonTransactionResponse)
        end
      end

      it 'initiates an asynchronous VAProfile transaction', :aggregate_failures do
        VCR.use_cassette('va_profile/person/init_vet360_id_success', VCR::MATCH_EVERYTHING) do
          response = subject.init_vet360_id(icn)

          expect(response.transaction.id).to be_present
          expect(response.transaction.status).to be_present
        end
      end
    end

    context 'with a 400 response' do
      it 'raises an exception', :aggregate_failures do
        VCR.use_cassette('va_profile/person/init_vet360_id_status_400', VCR::MATCH_EVERYTHING) do
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
