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
    let(:mhv_assurance) { 'some-mhv-assurance' }
    let(:dslogon_assurance) { 'some-dslogon-assurance' }
    let(:sub) { 'some-sub-uuid' }
    let(:expected_auto_uplevel) { false }
    let(:user_info) do
      OpenStruct.new({ verified_at: verified_at,
                       credential_ial: credential_ial,
                       level_of_assurance: level_of_assurance,
                       mhv_assurance: mhv_assurance,
                       dslogon_assurance: dslogon_assurance,
                       sub: sub })
    end
    let(:auto_uplevel) { false }

    before { allow(Settings.sign_in).to receive(:auto_uplevel).and_return(auto_uplevel) }

    shared_examples 'invalid credential level error' do
      let(:expected_error) { SignIn::Errors::InvalidCredentialLevelError }
      let(:expected_error_message) { 'Unsupported credential authorization levels' }

      it 'raises an invalid credential level error' do
        expect { subject }.to raise_error(expected_error, expected_error_message)
      end
    end

    context 'when requested_acr is arbitrary' do
      let(:requested_acr) { 'some-requested-acr' }

      it_behaves_like 'invalid credential level error'
    end

    context 'when type is arbitrary' do
      let(:type) { 'some-type' }

      it_behaves_like 'invalid credential level error'
    end

    shared_examples 'a created credential level' do
      it 'returns credential_level with expected attributes' do
        credential_level = subject
        expect(credential_level.requested_acr).to be(requested_acr)
        expect(credential_level.credential_type).to be(type)
        expect(credential_level.current_ial).to be(expected_current_ial)
        expect(credential_level.max_ial).to be(expected_max_ial)
        expect(credential_level.auto_uplevel).to be(expected_auto_uplevel)
      end
    end

    context 'when type is logingov' do
      let(:type) { SAML::User::LOGINGOV_CSID }

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

          shared_examples 'an auto-uplevel capable credential' do
            context 'and user has previously authenticated as a verified user' do
              let!(:user_verification) { create(:logingov_user_verification, logingov_uuid: sub) }

              context 'and sign_in auto_uplevel settings is false' do
                let(:auto_uplevel) { false }
                let(:expected_current_ial) { IAL::ONE }
                let(:expected_auto_uplevel) { false }

                it_behaves_like 'a created credential level'
              end

              context 'and sign_in auto_uplevel settings is true' do
                let(:auto_uplevel) { true }

                it_behaves_like 'a created credential level'
              end
            end

            context 'and user has not previously authenticated as a verified user' do
              let(:expected_current_ial) { IAL::ONE }
              let(:expected_auto_uplevel) { false }

              it_behaves_like 'a created credential level'
            end
          end

          context 'and requested_acr is set to ial2' do
            let(:requested_acr) { SignIn::Constants::Auth::IAL2 }
            let(:expected_current_ial) { IAL::TWO }
            let(:expected_auto_uplevel) { true }

            it_behaves_like 'an auto-uplevel capable credential'
          end

          context 'and requested_acr is set to min' do
            let(:requested_acr) { SignIn::Constants::Auth::MIN }
            let(:expected_current_ial) { IAL::TWO }
            let(:expected_auto_uplevel) { true }

            it_behaves_like 'an auto-uplevel capable credential'
          end

          context 'and requested_acr is set to ial1' do
            let(:requested_acr) { SignIn::Constants::Auth::IAL1 }
            let(:expected_current_ial) { IAL::ONE }

            it_behaves_like 'an auto-uplevel capable credential'
          end
        end
      end

      context 'and user info does not have verified_at trait' do
        let(:verified_at) { nil }
        let(:expected_max_ial) { IAL::ONE }

        context 'and id token acr is defined as IAL 2' do
          let(:id_token_payload) { { acr: IAL::LOGIN_GOV_IAL2 } }
          let(:expected_current_ial) { IAL::TWO }

          it_behaves_like 'invalid credential level error'
        end

        context 'and id token acr is not defined as IAL 2' do
          let(:id_token_payload) { 'some-id-token-payload' }
          let(:expected_current_ial) { IAL::ONE }

          it_behaves_like 'a created credential level'
        end
      end
    end

    context 'when type is mhv' do
      let(:type) { SAML::User::MHV_ORIGINAL_CSID }

      context 'and mhv assurance is set to premium' do
        let(:mhv_assurance) { 'Premium' }
        let(:expected_max_ial) { IAL::TWO }

        context 'and requested_acr is set to loa3' do
          let(:requested_acr) { SignIn::Constants::Auth::LOA3 }
          let(:expected_current_ial) { IAL::TWO }

          it_behaves_like 'a created credential level'
        end

        context 'and requested_acr is set to min' do
          let(:requested_acr) { SignIn::Constants::Auth::MIN }
          let(:expected_current_ial) { IAL::TWO }

          it_behaves_like 'a created credential level'
        end

        context 'and requested_acr is set to loa1' do
          let(:requested_acr) { SignIn::Constants::Auth::LOA1 }
          let(:expected_current_ial) { IAL::ONE }

          it_behaves_like 'a created credential level'
        end
      end

      context 'and mhv assurance is not set to premium' do
        let(:mhv_assurance) { 'some-mhv-assurance' }
        let(:expected_max_ial) { IAL::ONE }
        let(:expected_current_ial) { IAL::ONE }

        it_behaves_like 'a created credential level'
      end
    end

    context 'when type is dslogon' do
      let(:type) { SAML::User::DSLOGON_CSID }
      let(:expected_rails_log) { "[CredentialLevelCreator] DSLogon level of assurance #{dslogon_assurance}" }

      it 'logs the dslogon assurance from the user info' do
        expect(Rails.logger).to receive(:info).with(expected_rails_log)
        subject
      end

      context 'and dslogon assurance is set to dslogon assurance two' do
        let(:dslogon_assurance) { LOA::DSLOGON_ASSURANCE_TWO }
        let(:expected_max_ial) { IAL::TWO }

        context 'and requested_acr is set to loa3' do
          let(:requested_acr) { SignIn::Constants::Auth::LOA3 }
          let(:expected_current_ial) { IAL::TWO }

          it_behaves_like 'a created credential level'
        end

        context 'and requested_acr is set to min' do
          let(:requested_acr) { SignIn::Constants::Auth::MIN }
          let(:expected_current_ial) { IAL::TWO }

          it_behaves_like 'a created credential level'
        end

        context 'and requested_acr is set to loa1' do
          let(:requested_acr) { SignIn::Constants::Auth::LOA1 }
          let(:expected_current_ial) { IAL::ONE }

          it_behaves_like 'a created credential level'
        end
      end

      context 'and dslogon assurance is set to 3' do
        let(:dslogon_assurance) { LOA::DSLOGON_ASSURANCE_THREE }
        let(:expected_max_ial) { IAL::TWO }

        context 'and requested_acr is set to loa3' do
          let(:requested_acr) { SignIn::Constants::Auth::LOA3 }
          let(:expected_current_ial) { IAL::TWO }

          it_behaves_like 'a created credential level'
        end

        context 'and requested_acr is set to min' do
          let(:requested_acr) { SignIn::Constants::Auth::MIN }
          let(:expected_current_ial) { IAL::TWO }

          it_behaves_like 'a created credential level'
        end

        context 'and requested_acr is set to loa1' do
          let(:requested_acr) { SignIn::Constants::Auth::LOA1 }
          let(:expected_current_ial) { IAL::ONE }

          it_behaves_like 'a created credential level'
        end
      end

      context 'and dslogon assurance is set to an arbitrary value' do
        let(:dslogon_assurance) { 'some-dslogon-assurance' }
        let(:expected_max_ial) { IAL::ONE }
        let(:expected_current_ial) { IAL::ONE }

        it_behaves_like 'a created credential level'
      end
    end

    context 'when type is some other supported value' do
      let(:type) { SAML::User::IDME_CSID }

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

          shared_examples 'an auto-uplevel capable credential' do
            context 'and user has previously authenticated as a verified user' do
              let!(:user_verification) { create(:idme_user_verification, idme_uuid: sub) }

              context 'and sign_in auto_uplevel settings is false' do
                let(:auto_uplevel) { false }
                let(:expected_current_ial) { IAL::ONE }
                let(:expected_auto_uplevel) { false }

                it_behaves_like 'a created credential level'
              end

              context 'and sign_in auto_uplevel settings is true' do
                let(:auto_uplevel) { true }

                it_behaves_like 'a created credential level'
              end
            end

            context 'and user has not previously authenticated as a verified user' do
              let(:expected_current_ial) { IAL::ONE }
              let(:expected_auto_uplevel) { false }

              it_behaves_like 'a created credential level'
            end
          end

          context 'and requested_acr is set to loa3' do
            let(:requested_acr) { SignIn::Constants::Auth::LOA3 }
            let(:expected_current_ial) { IAL::TWO }
            let(:expected_auto_uplevel) { true }

            it_behaves_like 'an auto-uplevel capable credential'
          end

          context 'and requested_acr is set to min' do
            let(:requested_acr) { SignIn::Constants::Auth::MIN }
            let(:expected_current_ial) { IAL::TWO }
            let(:expected_auto_uplevel) { true }

            it_behaves_like 'an auto-uplevel capable credential'
          end

          context 'and requested_acr is set to ial1' do
            let(:requested_acr) { SignIn::Constants::Auth::LOA1 }
            let(:expected_current_ial) { IAL::ONE }

            it_behaves_like 'an auto-uplevel capable credential'
          end
        end
      end

      context 'and user info level of assurance does not equal idme classic loa3' do
        let(:level_of_assurance) { 'some-level-of-assurance' }
        let(:expected_max_ial) { IAL::ONE }

        context 'and user info credential ial equals idme classic loa3' do
          let(:credential_ial) { LOA::IDME_CLASSIC_LOA3 }
          let(:expected_current_ial) { IAL::TWO }

          it_behaves_like 'invalid credential level error'
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
