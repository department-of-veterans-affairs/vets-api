# frozen_string_literal: true

require 'rails_helper'
require_relative '../support/helpers/rails_helper'

describe Mobile::V0::Profile::SyncUpdateService do
  let(:service) { Mobile::V0::Profile::SyncUpdateService.new(user) }

  before do
    allow(Flipper).to receive(:enabled?).with(:mobile_v2_contact_info, instance_of(User)).and_return(true)
    allow(Flipper).to receive(:enabled?).with(:va_v3_contact_information_service, instance_of(User)).and_return(true)
    allow(Flipper).to receive(:enabled?).with(:remove_pciu, instance_of(User)).and_return(false)
  end

  describe '#v2_save_and_await_response' do
    let(:user) { create(:user, :api_auth_v2) }

    let(:params) { build(:va_profile_v3_address, :v2_override, validation_key: nil) }

    context 'when it succeeds' do
      let(:transaction) do
        VCR.use_cassette('va_profile/v2/contact_information/put_address_transaction_status', VCR::MATCH_EVERYTHING) do
          VCR.use_cassette('va_profile/v2/contact_information/put_address_success', VCR::MATCH_EVERYTHING) do
            service.save_and_await_response(resource_type: :address, params:, update: true)
          end
        end
      end
    end

    context 'when it succeeds after one incomplete status check' do
      let(:transaction) do
        VCR.use_cassette('va_profile/v3/contact_information/address_transaction_status', VCR::MATCH_EVERYTHING) do
          VCR.use_cassette('va_profile/v3/contact_information/get_address_status_incomplete', VCR::MATCH_EVERYTHING) do
            VCR.use_cassette('va_profile/v3/contact_information/put_address_initial', match_requests_on: %i[uri method headers]) do
              service.save_and_await_response(resource_type: :address, params:, update: true)
            end
          end
        end
      end

      it 'has a completed va.gov async status' do
        expect(transaction.status).to eq('completed')
      end

      it 'has a COMPLETED_SUCCESS vet360 transaction status' do
        expect(transaction.transaction_status).to eq('COMPLETED_SUCCESS')
      end
    end

    context 'when it succeeds after two incomplete checks' do
      let(:transaction) do
        VCR.use_cassette('va_profile/v3/contact_information/get_address_status_complete', VCR::MATCH_EVERYTHING) do
          VCR.use_cassette('va_profile/v3/contact_information/get_address_status_incomplete_2', VCR::MATCH_EVERYTHING) do
            VCR.use_cassette('va_profile/v3/contact_information/get_address_status_incomplete', VCR::MATCH_EVERYTHING) do
              VCR.use_cassette('va_profile/v3/contact_information/put_address_initial', match_requests_on: %i[uri method headers]) do
                service.save_and_await_response(resource_type: :address, params:, update: true)
              end
            end
          end
        end
      end

      it 'has a completed va.gov async status' do
        expect(transaction.status).to eq('completed')
      end

      it 'has a COMPLETED_SUCCESS vet360 transaction status' do
        expect(transaction.transaction_status).to eq('COMPLETED_SUCCESS')
      end
    end

    context 'when it has not completed within the timeout window (< 60s)' do
      before do
        allow_any_instance_of(Mobile::V0::Profile::SyncUpdateService).to receive(:seconds_elapsed_since).and_return(61)
        allow_any_instance_of(Mobile::V0::Profile::SyncUpdateService).to receive(:check_transaction_status!)
          .and_raise(Mobile::V0::Profile::IncompleteTransaction)
      end

      it 'raises a gateway timeout error' do
        VCR.use_cassette('va_profile/v3/contact_information/get_address_status_complete', VCR::MATCH_EVERYTHING) do
          VCR.use_cassette('va_profile/v3/contact_information/get_address_status_incomplete_2', VCR::MATCH_EVERYTHING) do
            VCR.use_cassette('va_profile/v3/contact_information/get_address_status_incomplete', VCR::MATCH_EVERYTHING) do
              VCR.use_cassette('va_profile/v3/contact_information/put_address_initial', match_requests_on: %i[uri method headers]) do
                expect { service.save_and_await_response(resource_type: :address, params:, update: true) }
                  .to raise_error(Common::Exceptions::GatewayTimeout)
              end
            end
          end
        end
      end
    end

    context 'when it fails on a status check returning an error' do
      it 'raises a backend service exception' do
        VCR.use_cassette('va_profile/v3/contact_information/get_address_status_error', VCR::MATCH_EVERYTHING) do
          VCR.use_cassette('va_profile/v3/contact_information/put_address_initial', match_requests_on: %i[uri method headers]) do
            expect { service.save_and_await_response(resource_type: :address, params:, update: true) }
              .to raise_error(Common::Exceptions::BackendServiceException)
          end
        end
      end
    end
  end
end
