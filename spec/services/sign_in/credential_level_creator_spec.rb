# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SignIn::CredentialLevelCreator do
  describe '#perform' do
    subject do
      SignIn::CredentialLevelCreator.new(requested_acr: requested_acr,
                                         type: type,
                                         id_token: id_token,
                                         user_info: user_info).perform
    end

    let(:requested_acr) { SignIn::Constants::Auth::ACR_VALUES.first }
    let(:type) { SignIn::Constants::Auth::REDIRECT_URLS.first }
    let(:id_token) { JWT.encode(id_token_payload, OpenSSL::PKey::RSA.new(2048), 'RS256') }
    let(:id_token_payload) { 'some-id-token' }
    let(:verified_at) { Time.zone.now }
    let(:credential_ial) { IAL::ONE }
    let(:level_of_assurance) { LOA::IDME_CLASSIC_LOA3 }
    let(:user_info) do
      OpenStruct.new({ verified_at: verified_at,
                       credential_ial: credential_ial,
                       level_of_assurance: level_of_assurance })
    end

    context 'when requested_acr is arbitrary' do
      let(:requested_acr) { 'some-requested-acr' }
      let(:expected_error) { SignIn::Errors::InvalidCredentialLevelError }
      let(:expected_error_message) { 'Unsupported credential authorization levels' }

      it 'raises an invalid credential level error' do
        expect { subject }.to raise_error(expected_error, expected_error_message)
      end
    end

    context 'when type is arbitrary' do
      let(:type) { 'some-type' }
      let(:expected_error) { SignIn::Errors::InvalidCredentialLevelError }
      let(:expected_error_message) { 'Unsupported credential authorization levels' }

      it 'raises an invalid credential level error' do
        expect { subject }.to raise_error(expected_error, expected_error_message)
      end
    end

    shared_examples 'a created credential level' do
      it 'returns credential_level with expected attributes' do
        credential_level = subject
        expect(credential_level.requested_acr).to be(requested_acr)
        expect(credential_level.credential_type).to be(type)
        expect(credential_level.current_ial).to be(expected_current_ial)
        expect(credential_level.max_ial).to be(expected_max_ial)
      end
    end

    context 'and type is logingov' do
      let(:type) { 'logingov' }

      context 'and user info has verified_at trait' do
        let(:verified_at) { Time.zone.now }
        let(:expected_max_ial) { IAL::TWO }

        context 'and id token acr is defined as IAL 2' do
          let(:id_token_payload) { { acr: IAL::LOGIN_GOV_IAL2 } }
          let(:expected_current_ial) { IAL::TWO }

          it_behaves_like 'a created credential level'
        end

        context 'and id token acr is not defined as IAL 2' do
          let(:id_token_payload) { 'some-id-token-payload' }
          let(:expected_current_ial) { IAL::ONE }

          it_behaves_like 'a created credential level'
        end
      end

      context 'and user info does not have verified_at trait' do
        let(:verified_at) { nil }
        let(:expected_max_ial) { IAL::ONE }

        context 'and id token acr is defined as IAL 2' do
          let(:id_token_payload) { { acr: IAL::LOGIN_GOV_IAL2 } }
          let(:expected_current_ial) { IAL::TWO }

          it_behaves_like 'a created credential level'
        end

        context 'and id token acr is not defined as IAL 2' do
          let(:id_token_payload) { 'some-id-token-payload' }
          let(:expected_current_ial) { IAL::ONE }

          it_behaves_like 'a created credential level'
        end
      end
    end

    context 'and type is some other supported value' do
      let(:type) { 'idme' }

      context 'and user info level of assurance equals idme classic loa3' do
        let(:level_of_assurance) { LOA::THREE }
        let(:expected_max_ial) { IAL::TWO }

        context 'and user info credential ial equals idme classic loa3' do
          let(:credential_ial) { LOA::IDME_CLASSIC_LOA3 }
          let(:expected_current_ial) { IAL::TWO }

          it_behaves_like 'a created credential level'
        end

        context 'and user info credential ial does not equal idme classic loa3' do
          let(:credential_ial) { 'some-credential-ial' }
          let(:expected_current_ial) { IAL::ONE }

          it_behaves_like 'a created credential level'
        end
      end

      context 'and user info level of assurance does not equal idme classi loa3' do
        let(:level_of_assurance) { 'some-level-of-assurance' }
        let(:expected_max_ial) { IAL::ONE }

        context 'and user info credential ial equals idme classic loa3' do
          let(:credential_ial) { LOA::IDME_CLASSIC_LOA3 }
          let(:expected_current_ial) { IAL::TWO }

          it_behaves_like 'a created credential level'
        end

        context 'and user info credential ial does not equal idme classic loa3' do
          let(:credential_ial) { 'some-credential-ial' }
          let(:expected_current_ial) { IAL::ONE }

          it_behaves_like 'a created credential level'
        end
      end
    end
  end
end
