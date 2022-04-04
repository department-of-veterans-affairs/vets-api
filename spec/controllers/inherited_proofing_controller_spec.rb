# frozen_string_literal: true

require 'rails_helper'
require 'support/controller_spec_helper'

RSpec.describe InheritedProofingController, type: :controller do
  describe 'GET auth' do
    subject { get(:auth) }

    context 'when user is not authenticated' do
      it 'returns a 401' do
        expect(subject.response_code).to eq(401)
      end
    end

    context 'authenticated user' do
      let(:icn) { '1013459302V141714' }
      let(:correlation_id) { '19031408' }
      let(:identity_info_url) { "#{Settings.mhv.inherited_proofing.base_path}/mhvacctinfo/#{correlation_id}" }
      let(:current_user) do
        build(:user, :mhv,
              mhv_icn: icn,
              mhv_correlation_id: correlation_id)
      end

      before { sign_in_as(current_user) }

      context 'MHV eligible' do
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
        let(:auth_code) { SecureRandom.hex }

        before do
          stub_request(:get, identity_info_url).to_return(
            body: identity_data_response.to_json
          )
          allow(SecureRandom).to receive(:hex).and_return(auth_code)
        end

        it 'renders Login.gov OAuth form with the MHV verifier auth_code' do
          expect(subject.response_code).to eq(200)
          expect(subject.body).to include("id=\"inherited_proofing_auth\" value=\"#{auth_code}\"")
        end
      end

      context 'MHV ineligible' do
        let(:identity_data_failed_response) do
          {
            'mhvId' => 9712240, # rubocop:disable Style/NumericLiterals
            'identityDocumentExist' => false
          }
        end

        before do
          stub_request(:get, identity_info_url).to_return(
            body: identity_data_failed_response.to_json
          )
        end

        it 'will return early' do
          expect(subject.response_code).to eq(400)
        end
      end
    end
  end
end
