# frozen_string_literal: true

require 'rails_helper'
require 'va_profile/v2/person/service'

describe VAProfile::V2::Person::Service, :skip_vet360 do
  before { Timecop.freeze('2024-09-16T16:09:37.000Z') }

  after  { Timecop.return }

  describe '#init_vet360_id' do
    subject { described_class.new(user) }

    let(:user) { build(:user, :loa3) }

    before do
      allow(Flipper).to receive(:enabled?).with(:remove_pciu, instance_of(User)).and_return(true)
    end

    context 'with a user present, that has a icn_with_aaid' do
      it 'returns a status of 200', :aggregate_failures do
        VCR.use_cassette('va_profile/v2/person/init_vet360_id_success', VCR::MATCH_EVERYTHING) do
          response = subject.init_vet360_id

          expect(response).to be_ok
          expect(response).to be_a(VAProfile::V2::ContactInformation::PersonTransactionResponse)
        end
      end

      it 'initiates an asynchronous VAProfile transaction', :aggregate_failures do
        VCR.use_cassette('va_profile/v2/person/init_vet360_id_success', VCR::MATCH_EVERYTHING) do
          response = subject.init_vet360_id

          expect(response.transaction.id).to be_present
          expect(response.transaction.status).to be_present
        end
      end
    end

    context 'with a 400 response' do
      let(:user) { build(:user, :loa3) }

      before do
        allow_any_instance_of(User).to receive(:vet360_id).and_return('6767671')
        allow_any_instance_of(User).to receive(:idme_uuid).and_return(nil)
      end

      it 'raises an exception', :aggregate_failures do
        VCR.use_cassette('va_profile/v2/person/init_vet360_id_status_400', VCR::MATCH_EVERYTHING) do
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
