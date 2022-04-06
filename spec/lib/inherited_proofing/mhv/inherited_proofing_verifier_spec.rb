# frozen_string_literal: true

require 'rails_helper'
require 'inherited_proofing/mhv/inherited_proofing_verifier'
require 'inherited_proofing/mhv/service'

describe InheritedProofing::MHV::InheritedProofingVerifier do
  let(:user) { FactoryBot.create(:user, :loa3) }
  let(:service_obj) { described_class.new(user) }
  let(:api_obj) { InheritedProofing::MHV::Service }
  let(:config_obj) { api_obj::ConfigMethods }
  let(:correlation_id) { 19031408 } # rubocop:disable Style/NumericLiterals
  let(:correlation_id_response) do
    {
      'correlationId' => correlation_id,
      'accountStatus' => 'Premium',
      'apiCompletionStatus' => 'Successful'
    }
  end
  let(:correlation_id_error_response) do
    {
      'errorCode' => 99,
      'developerMessage' => '',
      'message' => 'Unknown application error occurred'
    }
  end

  describe 'correlation_id' do
    context 'with existing correlation_id' do
      it 'will use existing user correlation_id if one exists' do
        expect(service_obj.send(:correlation_id)).to eq(user.mhv_correlation_id)
      end
    end

    context 'with no existing correlation_id' do
      before do
        allow_any_instance_of(User).to receive(:mhv_correlation_id).and_return(nil)
        allow(api_obj).to receive(:get_correlation_data).and_return(correlation_id_response)
      end

      it 'can sucessfully exchange ICN for correlation_id' do
        expect(service_obj.send(:correlation_id)).to eq(correlation_id)
      end
    end

    context 'when unable to find a user by ICN' do
      let(:expected_error) { InheritedProofing::Errors::IdentityDocumentMissingError }

      before do
        allow_any_instance_of(User).to receive(:mhv_correlation_id).and_return(nil)
        allow(api_obj).to receive(:get_correlation_data).and_return(correlation_id_error_response)
      end

      it 'will return identity document missing error if user is not found' do
        expect(service_obj.send(:correlation_id)).to eq(nil)
        expect { service_obj.perform }.to raise_error(expected_error)
      end
    end

    context 'with application error' do
      let(:expected_error) { InheritedProofing::Errors::IdentityDocumentMissingError }

      before do
        allow_any_instance_of(User).to receive(:mhv_correlation_id).and_return(nil)
        allow_any_instance_of(config_obj).to receive(:perform).and_raise(Common::Client::Errors::ClientError)
      end

      it 'will return identity document missing error if mhv service is down' do
        expect(service_obj.send(:correlation_id)).to eq(nil)
        expect { service_obj.perform }.to raise_error(expected_error)
      end
    end
  end

  describe 'identity_info' do
    context 'when user is found and eligible' do
      let(:identity_data_response) do
        {
          'mhvId' => 19031205, # rubocop:disable Style/NumericLiterals
          'identityProofedMethod' => 'IPA',
          'identityProofingDate' => '2020-12-14',
          'identityDocumentExist' => true,
          'identityDocumentInfo' => {
            'primaryIdentityDocumentNumber' => '73929233',
            'primaryIdentityDocumentType' => 'StateIssuedId',
            'primaryIdentityDocumentCountry' => 'United States',
            'primaryIdentityDocumentExpirationDate' => '2026-03-30'
          }
        }
      end
      let(:code) { SecureRandom.hex }

      before do
        allow(api_obj).to receive(:get_verification_data).and_return(identity_data_response)
        allow_any_instance_of(described_class).to receive(:code).and_return(code)
      end

      it 'will return hash if user has identity proof' do
        expect(service_obj.send(:identity_info)).to eq(identity_data_response)
      end

      it 'will cache information' do
        service_obj.perform
        expect(InheritedProofing::MHVIdentityData.find(code)).not_to be_nil
      end

      it 'will return code' do
        expect(service_obj.perform).to eq(code)
      end
    end

    context 'when user is found and not eligible' do
      let(:identity_data_failed_response) do
        {
          'mhvId' => 9712240, # rubocop:disable Style/NumericLiterals
          'identityDocumentExist' => false
        }
      end
      let(:expected_error) { InheritedProofing::Errors::IdentityDocumentMissingError }

      before do
        allow(api_obj).to receive(:get_verification_data).and_return(identity_data_failed_response)
      end

      it 'will return empty hash if user does not have identity proof' do
        expect(service_obj.send(:identity_info)).to eq(identity_data_failed_response)
      end

      it 'will raise identity document missing error, and will not cache any data' do
        expect { service_obj.perform }.to raise_error(expected_error)
        expect(InheritedProofing::MHVIdentityData.keys).to be_blank
      end
    end

    context 'with application error' do
      let(:expected_error) { InheritedProofing::Errors::IdentityDocumentMissingError }

      before do
        allow_any_instance_of(config_obj).to receive(:perform).and_raise(Common::Client::Errors::ClientError)
      end

      it 'will return empty hash if mhv service is down' do
        expect(service_obj.send(:identity_info)).to eq({})
      end

      it 'will raise identity document missing error, and will not cache any data' do
        expect { service_obj.perform }.to raise_error(expected_error)
        expect(InheritedProofing::MHVIdentityData.keys).to be_blank
      end
    end
  end
end
