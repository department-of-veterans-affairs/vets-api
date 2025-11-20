# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Sts::TermsOfUseController, type: :controller do
  let(:service_account_config) { create(:service_account_config, scopes:) }
  let(:service_account_id) { service_account_config.service_account_id }
  let(:scopes) { ['http://www.example.com/sts/terms_of_use'] }
  let(:service_account_access_token) do
    create(:service_account_access_token, service_account_id:, scopes:, user_attributes: { icn: })
  end
  let(:sts_token) do
    SignIn::ServiceAccountAccessTokenJwtEncoder.new(service_account_access_token:).perform
  end
  let!(:current_terms_of_use_agreement) { create(:terms_of_use_agreement, user_account:) }
  let!(:user_account) { create(:user_account) }
  let(:icn) { user_account&.icn }
  let(:response_body) { JSON.parse(response.body) }
  let(:expected_log_message) { '[Sts][TermsOfUseController] current_status success' }

  before do
    controller.request.headers['Authorization'] = "Bearer #{sts_token}"
    allow(Rails.logger).to receive(:info)
  end

  describe 'GET #current_status' do
    before { get :current_status }

    context 'when authenticated' do
      shared_examples 'logs a success message' do
        it 'logs a success message' do
          expect(Rails.logger).to have_received(:info).with(expected_log_message, icn:)
        end
      end

      context 'with an existing terms of use agreement' do
        it 'returns a success response with the agreement status' do
          expect(response).to be_successful
          expect(response_body['agreement_status']).to eq(current_terms_of_use_agreement.response)
        end

        include_examples 'logs a success message'

        context 'with metadata included' do
          context 'when agreement is accepted' do
            before { get :current_status, params: { metadata: 'true' } }

            it 'returns the agreement status with metadata' do
              expect(response).to be_successful
              expect(response_body['agreement_status']).to eq(current_terms_of_use_agreement.response)
              expect(response_body['metadata']).to include(
                'va_terms_of_use_doc_title' => MHV::AccountCreation::Configuration::TOU_DOC_TITLE,
                'va_terms_of_use_legal_version' => MHV::AccountCreation::Configuration::TOU_LEGAL_VERSION,
                'va_terms_of_use_revision' => MHV::AccountCreation::Configuration::TOU_REVISION,
                'va_terms_of_use_status' => MHV::AccountCreation::Configuration::TOU_STATUS,
                'va_terms_of_use_datetime' => current_terms_of_use_agreement.created_at.as_json
              )
            end
          end

          context 'when agreement is declined' do
            let!(:current_terms_of_use_agreement) do
              create(:terms_of_use_agreement, user_account:, response: :declined)
            end

            before { get :current_status, params: { metadata: 'true' } }

            it 'returns the agreement status without the metadata' do
              expect(response).to be_successful
              expect(response_body['agreement_status']).to eq(current_terms_of_use_agreement.response)
              expect(response_body['metadata']).to be_nil
            end
          end
        end
      end

      context 'without an existing terms of use agreement' do
        let(:current_terms_of_use_agreement) { nil }

        it 'returns a success response with a nil agreement status' do
          expect(response).to be_successful
          expect(response_body['agreement_status']).to be_nil
        end

        include_examples 'logs a success message'

        context 'with metadata included' do
          before { get :current_status, params: { metadata: 'true' } }

          it 'returns a success response with nil metadata' do
            expect(response).to be_successful
            expect(response_body['agreement_status']).to be_nil
            expect(response_body['metadata']).to be_nil
          end
        end
      end

      context 'when user account does not exist' do
        let(:user_account) { nil }
        let(:current_terms_of_use_agreement) { nil }

        it 'returns a success response with a nil agreement status' do
          expect(response).to be_successful
          expect(response_body['agreement_status']).to be_nil
        end

        include_examples 'logs a success message'
      end
    end

    context 'when not authenticated' do
      let(:sts_token) { 'invalid_token' }

      it 'returns an unauthorized response' do
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
