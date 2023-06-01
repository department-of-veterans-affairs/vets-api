# frozen_string_literal: true

require 'rails_helper'
require_relative '../support/helpers/iam_session_helper'

describe Mobile::V0::Profile::SyncUpdateService do
  let(:user) { FactoryBot.build(:iam_user) }
  let(:service) { Mobile::V0::Profile::SyncUpdateService.new(user) }

  before { iam_sign_in(user) }

  describe '#save_and_await_response' do
    let(:params) { build(:va_profile_address, vet360_id: user.vet360_id, validation_key: nil) }

    context 'when it succeeds after one incomplete status check' do
      let(:transaction) do
        VCR.use_cassette('mobile/profile/get_address_status_complete') do
          VCR.use_cassette('mobile/profile/get_address_status_incomplete') do
            VCR.use_cassette('mobile/profile/put_address_initial') do
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
        VCR.use_cassette('mobile/profile/get_address_status_complete') do
          VCR.use_cassette('mobile/profile/get_address_status_incomplete_2') do
            VCR.use_cassette('mobile/profile/get_address_status_incomplete') do
              VCR.use_cassette('mobile/profile/put_address_initial') do
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
      end

      it 'raises a gateway timeout error' do
        VCR.use_cassette('mobile/profile/get_address_status_complete') do
          VCR.use_cassette('mobile/profile/get_address_status_incomplete_2') do
            VCR.use_cassette('mobile/profile/get_address_status_incomplete') do
              VCR.use_cassette('mobile/profile/put_address_initial') do
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
        VCR.use_cassette('mobile/profile/get_address_status_error') do
          VCR.use_cassette('mobile/profile/put_address_initial') do
            expect { service.save_and_await_response(resource_type: :address, params:, update: true) }
              .to raise_error(Common::Exceptions::BackendServiceException)
          end
        end
      end
    end
  end
end
