# frozen_string_literal: true

require 'rails_helper'

describe Mobile::V0::Profile::SyncUpdateService do
  let(:user) { create(:user, :api_auth) }
  let(:service) { Mobile::V0::Profile::SyncUpdateService.new(user) }

  # DO THIS
  describe '#save_and_await_response' do
    before do
      Flipper.disable(:va_v3_contact_information_service)
    end

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

  # Correct in another PR
  # describe '#v2_save_and_await_response' do
  #   before do
  #     allow(Flipper).to receive(:enabled?).with(:va_v3_contact_information_service).and_return(true)
  #   end

  #   after do
  #     Flipper.disable(:va_v3_contact_information_service)
  #   end

  #   let(:user) { create(:user, :api_auth_v2) }

  #   let(:params) { build(:va_profile_v3_address, :override, validation_key: nil) }

  #   context 'when it succeeds' do
  #     let(:transaction) do
  #       VCR.use_cassette('va_profile/v2/put_address_transaction_status') do
  #         VCR.use_cassette('va_profile/v2/contact_information/put_address_success') do
  #           service.save_and_await_response(resource_type: :address, params:, update: true)
  #   let(:params) { build(:va_profile_address, :contact_info_v2, validation_key: nil) }

  #   context 'when it succeeds after one incomplete status check' do
  #     let(:transaction) do
  #       VCR.use_cassette('va_profile/v2/contact_information/address_transaction_status') do
  #         VCR.use_cassette('mobile/profile/get_address_status_incomplete') do
  #           VCR.use_cassette('mobile/profile/put_address_initial') do
  #             service.save_and_await_response(resource_type: :address, params:, update: true)
  #           end
  #         end
  #       end
  #     end

  #     it 'has a completed va.gov async status' do
  #       expect(transaction.status).to eq('completed')
  #     end

  #     it 'has a COMPLETED_SUCCESS vet360 transaction status' do
  #       expect(transaction.transaction_status).to eq('COMPLETED_SUCCESS')
  #     end
  #   end

  #   context 'when it succeeds after two incomplete checks' do
  #     let(:transaction) do
  #       VCR.use_cassette('mobile/profile/get_address_status_complete') do
  #         VCR.use_cassette('mobile/profile/get_address_status_incomplete_2') do
  #           VCR.use_cassette('mobile/profile/get_address_status_incomplete') do
  #             VCR.use_cassette('mobile/profile/put_address_initial') do
  #               service.save_and_await_response(resource_type: :address, params:, update: true)
  #             end
  #           end
  #         end
  #       end
  #     end

  #     it 'has a completed va.gov async status' do
  #       expect(transaction.status).to eq('completed')
  #     end

  #     it 'has a COMPLETED_SUCCESS vet360 transaction status' do
  #       expect(transaction.transaction_status).to eq('COMPLETED_SUCCESS')
  #     end
  #   end

  #   context 'when it has not completed within the timeout window (< 60s)' do
  #     before do
  #       allow_any_instance_of(Mobile::V0::Profile::SyncUpdateService).to
  #         receive(:seconds_elapsed_since).and_return(61)
  #     end

  #     it 'raises a gateway timeout error' do
  #       VCR.use_cassette('mobile/profile/get_address_status_complete') do
  #         VCR.use_cassette('mobile/profile/get_address_status_incomplete_2') do
  #           VCR.use_cassette('mobile/profile/get_address_status_incomplete') do
  #             VCR.use_cassette('mobile/profile/put_address_initial') do
  #               expect { service.save_and_await_response(resource_type: :address, params:, update: true) }
  #                 .to raise_error(Common::Exceptions::GatewayTimeout)
  #             end
  #           end
  #         end
  #       end
  #     end
  #   end

  #   context 'when it fails on a status check returning an error' do
  #     it 'raises a backend service exception' do
  #       VCR.use_cassette('mobile/profile/get_address_status_error') do
  #         VCR.use_cassette('mobile/profile/put_address_initial') do
  #           expect { service.save_and_await_response(resource_type: :address, params:, update: true) }
  #             .to raise_error(Common::Exceptions::BackendServiceException)
  #         end
  #       end
  #     end
  #   end
  # end
end
