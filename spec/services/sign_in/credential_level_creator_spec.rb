# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SignIn::CredentialLevelCreator do
  describe '#perform' do
    subject do
      SignIn::CredentialLevelCreator.new(requested_acr:,
                                         type:,
                                         logingov_acr:,
                                         user_info:).perform
    end

    let(:requested_acr) { SignIn::Constants::Auth::ACR_VALUES.first }
    let(:type) { SignIn::Constants::Auth::CSP_TYPES.first }
    let(:logingov_acr) { 'some-acr' }
    let(:verified_at) { Time.zone.now }
    let(:credential_ial) { SignIn::Constants::Auth::IAL_ONE }
    let(:level_of_assurance) { SignIn::Constants::Auth::IDME_CLASSIC_LOA3 }
    let(:mhv_assurance) { 'some-mhv-assurance' }
    let(:sub) { 'some-sub-uuid' }
    let(:expected_auto_uplevel) { false }
    let(:user_info) do
      OpenStruct.new({ verified_at:,
                       credential_ial:,
                       level_of_assurance:,
                       mhv_assurance:,
                       sub: })
    end

    before do
      allow(Rails.logger).to receive(:info)
    end

    shared_examples 'invalid credential level error' do
      let(:expected_error) { SignIn::Errors::InvalidCredentialLevelError }
      let(:expected_error_message) { 'Unsupported credential authorization levels' }
      let(:expected_error_log) { "[SignIn][CredentialLevelCreator] error: #{validation_error_message}" }

      it 'raises an invalid credential level error' do
        expect { subject }.to raise_error(expected_error, expected_error_message)
        expect(Rails.logger).to have_received(:info).with(expected_error_log,
                                                          credential_type: type,
                                                          requested_acr:,
                                                          current_ial: expected_current_ial,
                                                          max_ial: expected_max_ial,
                                                          credential_uuid: sub)
      end
    end

    shared_examples 'unverified credential blocked error' do
      let(:expected_error) { SignIn::Errors::UnverifiedCredentialBlockedError }
      let(:expected_error_message) { 'Unverified credential for authorization requiring verified credential' }

      it 'raises an unverified credential blocked error' do
        expect { subject }.to raise_error(expected_error, expected_error_message)
      end

      it 'adds the expected error code to the raised error' do
        subject
      rescue => e
        expect(e.code).to eq(expected_error_code)
      end
    end

    context 'when requested_acr is arbitrary' do
      let(:requested_acr) { 'some-requested-acr' }
      let(:validation_error_message) { 'Validation failed: Requested acr is not included in the list' }
      let(:expected_current_ial) { SignIn::Constants::Auth::IAL_ONE }
      let(:expected_max_ial) { SignIn::Constants::Auth::IAL_ONE }

      it_behaves_like 'invalid credential level error'
    end

    context 'when type is arbitrary' do
      let(:type) { 'some-type' }
      let(:validation_error_message) { 'Validation failed: Credential type is not included in the list' }
      let(:expected_current_ial) { SignIn::Constants::Auth::IAL_ONE }
      let(:expected_max_ial) { SignIn::Constants::Auth::IAL_ONE }

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
      let(:type) { SignIn::Constants::Auth::LOGINGOV }

      context 'and user info has verified_at trait' do
        let(:verified_at) { Time.zone.now }
        let(:expected_max_ial) { SignIn::Constants::Auth::IAL_TWO }

        context 'and logingov acr is defined as IAL 2' do
          let(:logingov_acr) { SignIn::Constants::Auth::LOGIN_GOV_IAL2 }
          let(:expected_current_ial) { SignIn::Constants::Auth::IAL_TWO }

          it_behaves_like 'a created credential level'
        end

        context 'and logingov acr is not defined as IAL 2' do
          let(:logingov_acr) { 'some-acr' }
          let(:expected_current_ial) { SignIn::Constants::Auth::IAL_ONE }

          context 'and requested_acr is set to ial2' do
            let(:requested_acr) { SignIn::Constants::Auth::IAL2 }
            let(:expected_error_code) { SignIn::Constants::ErrorCode::GENERIC_EXTERNAL_ISSUE }

            it_behaves_like 'unverified credential blocked error'
          end

          context 'and requested_acr is set to min' do
            let(:requested_acr) { SignIn::Constants::Auth::MIN }

            it_behaves_like 'a created credential level'
          end

          context 'and requested_acr is set to ial1' do
            let(:requested_acr) { SignIn::Constants::Auth::IAL1 }

            it_behaves_like 'a created credential level'
          end
        end
      end

      context 'and user info does not have verified_at trait' do
        let(:verified_at) { nil }

        context 'and user has previously verified' do
          let!(:user_verification) { create(:logingov_user_verification, logingov_uuid: sub) }
          let(:expected_max_ial) { SignIn::Constants::Auth::IAL_TWO }

          context 'and logingov acr is defined as IAL 2' do
            let(:logingov_acr) { SignIn::Constants::Auth::LOGIN_GOV_IAL2 }
            let(:expected_current_ial) { SignIn::Constants::Auth::IAL_TWO }

            it_behaves_like 'a created credential level'
          end

          context 'and logingov acr is not defined as IAL 2' do
            let(:logingov_acr) { 'some-id-token-payload' }
            let(:expected_current_ial) { SignIn::Constants::Auth::IAL_ONE }

            it_behaves_like 'a created credential level'
          end
        end

        context 'and user has not previously verified' do
          let(:expected_max_ial) { SignIn::Constants::Auth::IAL_ONE }

          context 'and logingov acr is defined as IAL 2' do
            let(:logingov_acr) { SignIn::Constants::Auth::LOGIN_GOV_IAL2 }
            let(:expected_current_ial) { SignIn::Constants::Auth::IAL_TWO }
            let(:validation_error_message) { 'Validation failed: Max ial cannot be less than Current ial' }

            it_behaves_like 'invalid credential level error'
          end

          context 'and logingov acr is not defined as IAL 2' do
            let(:logingov_acr) { 'some-id-token-payload' }
            let(:expected_current_ial) { SignIn::Constants::Auth::IAL_ONE }

            it_behaves_like 'a created credential level'
          end
        end
      end
    end

    context 'when type is mhv' do
      let(:type) { SignIn::Constants::Auth::MHV }

      context 'and mhv assurance is set to premium' do
        let(:mhv_assurance) { 'Premium' }
        let(:expected_max_ial) { SignIn::Constants::Auth::IAL_TWO }

        context 'and requested_acr is set to loa3' do
          let(:requested_acr) { SignIn::Constants::Auth::LOA3 }
          let(:expected_current_ial) { SignIn::Constants::Auth::IAL_TWO }

          it_behaves_like 'a created credential level'
        end

        context 'and requested_acr is set to min' do
          let(:requested_acr) { SignIn::Constants::Auth::MIN }
          let(:expected_current_ial) { SignIn::Constants::Auth::IAL_TWO }

          it_behaves_like 'a created credential level'
        end

        context 'and requested_acr is set to loa1' do
          let(:requested_acr) { SignIn::Constants::Auth::LOA1 }
          let(:expected_current_ial) { SignIn::Constants::Auth::IAL_ONE }

          it_behaves_like 'a created credential level'
        end
      end

      context 'and mhv assurance is not set to premium' do
        let(:mhv_assurance) { 'some-mhv-assurance' }
        let(:expected_max_ial) { SignIn::Constants::Auth::IAL_ONE }

        context 'and requested_acr is set to loa3' do
          let(:requested_acr) { SignIn::Constants::Auth::LOA3 }
          let(:expected_error_code) { SignIn::Constants::ErrorCode::MHV_UNVERIFIED_BLOCKED }

          it_behaves_like 'unverified credential blocked error'
        end

        context 'and requested_acr is set to min' do
          let(:requested_acr) { SignIn::Constants::Auth::MIN }
          let(:expected_current_ial) { SignIn::Constants::Auth::IAL_ONE }

          it_behaves_like 'a created credential level'
        end

        context 'and requested_acr is set to loa1' do
          let(:requested_acr) { SignIn::Constants::Auth::LOA1 }
          let(:expected_current_ial) { SignIn::Constants::Auth::IAL_ONE }

          it_behaves_like 'a created credential level'
        end
      end
    end

    context 'when type is some other supported value' do
      let(:type) { SignIn::Constants::Auth::IDME }

      context 'and user info level of assurance equals idme classic loa3' do
        let(:level_of_assurance) { SignIn::Constants::Auth::LOA_THREE }
        let(:expected_max_ial) { SignIn::Constants::Auth::IAL_TWO }

        context 'and user info credential ial equals idme classic loa3' do
          let(:credential_ial) { SignIn::Constants::Auth::IDME_CLASSIC_LOA3 }
          let(:expected_current_ial) { SignIn::Constants::Auth::IAL_TWO }

          it_behaves_like 'a created credential level'
        end

        context 'and user info credential ial equals ial2' do
          let(:credential_ial) { SignIn::Constants::Auth::IAL_TWO }
          let(:expected_current_ial) { SignIn::Constants::Auth::IAL_TWO }

          it_behaves_like 'a created credential level'
        end

        context 'and user info credential ial is an arbitrary value' do
          let(:credential_ial) { 'some-credential-ial' }
          let(:expected_current_ial) { SignIn::Constants::Auth::IAL_ONE }

          context 'and requested_acr is set to loa3' do
            let(:requested_acr) { SignIn::Constants::Auth::LOA3 }
            let(:expected_error_code) { SignIn::Constants::ErrorCode::GENERIC_EXTERNAL_ISSUE }

            it_behaves_like 'unverified credential blocked error'
          end

          context 'and requested_acr is set to min' do
            let(:requested_acr) { SignIn::Constants::Auth::MIN }
            let(:expected_current_ial) { SignIn::Constants::Auth::IAL_ONE }

            it_behaves_like 'a created credential level'
          end

          context 'and requested_acr is set to ial1' do
            let(:requested_acr) { SignIn::Constants::Auth::LOA1 }
            let(:expected_current_ial) { SignIn::Constants::Auth::IAL_ONE }

            it_behaves_like 'a created credential level'
          end
        end
      end

      context 'and user info level of assurance does not equal idme classic loa3' do
        let(:level_of_assurance) { 'some-level-of-assurance' }
        let(:validation_error_message) { 'Validation failed: Max ial cannot be less than Current ial' }

        context 'and user has previously verified' do
          let(:expected_max_ial) { SignIn::Constants::Auth::IAL_TWO }
          let!(:user_verification) { create(:idme_user_verification, idme_uuid: sub) }

          context 'and user info credential ial equals idme classic loa3' do
            let(:credential_ial) { SignIn::Constants::Auth::IDME_CLASSIC_LOA3 }
            let(:expected_current_ial) { SignIn::Constants::Auth::IAL_TWO }

            it_behaves_like 'a created credential level'
          end

          context 'and user info credential ial equals ial2' do
            let(:credential_ial) { SignIn::Constants::Auth::IAL_TWO }
            let(:expected_current_ial) { SignIn::Constants::Auth::IAL_TWO }

            it_behaves_like 'a created credential level'
          end

          context 'and user info credential ial is an arbitrary value' do
            let(:credential_ial) { 'some-credential-ial' }
            let(:expected_current_ial) { SignIn::Constants::Auth::IAL_ONE }

            context 'and requested_acr is set to loa3' do
              let(:requested_acr) { SignIn::Constants::Auth::LOA3 }
              let(:expected_error_code) { SignIn::Constants::ErrorCode::GENERIC_EXTERNAL_ISSUE }

              it_behaves_like 'unverified credential blocked error'
            end

            context 'and requested_acr is set to min' do
              let(:requested_acr) { SignIn::Constants::Auth::MIN }
              let(:expected_current_ial) { SignIn::Constants::Auth::IAL_ONE }

              it_behaves_like 'a created credential level'
            end

            context 'and requested_acr is set to ial1' do
              let(:requested_acr) { SignIn::Constants::Auth::LOA1 }
              let(:expected_current_ial) { SignIn::Constants::Auth::IAL_ONE }

              it_behaves_like 'a created credential level'
            end
          end
        end

        context 'and user has not previously verified' do
          let(:expected_max_ial) { SignIn::Constants::Auth::IAL_ONE }

          context 'and user info credential ial equals idme classic loa3' do
            let(:credential_ial) { SignIn::Constants::Auth::IDME_CLASSIC_LOA3 }
            let(:expected_current_ial) { SignIn::Constants::Auth::IAL_TWO }

            it_behaves_like 'invalid credential level error'
          end

          context 'and user info credential ial equals ial2' do
            let(:credential_ial) { SignIn::Constants::Auth::IAL_TWO }
            let(:expected_current_ial) { SignIn::Constants::Auth::IAL_TWO }

            it_behaves_like 'invalid credential level error'
          end

          context 'and user info credential ial is an arbitrary value' do
            let(:credential_ial) { 'some-credential-ial' }
            let(:expected_current_ial) { SignIn::Constants::Auth::IAL_ONE }

            context 'and requested_acr is set to loa3' do
              let(:requested_acr) { SignIn::Constants::Auth::LOA3 }
              let(:expected_error_code) { SignIn::Constants::ErrorCode::GENERIC_EXTERNAL_ISSUE }

              it_behaves_like 'unverified credential blocked error'
            end

            context 'and requested_acr is set to min' do
              let(:requested_acr) { SignIn::Constants::Auth::MIN }
              let(:expected_current_ial) { SignIn::Constants::Auth::IAL_ONE }

              it_behaves_like 'a created credential level'
            end

            context 'and requested_acr is set to ial1' do
              let(:requested_acr) { SignIn::Constants::Auth::LOA1 }
              let(:expected_current_ial) { SignIn::Constants::Auth::IAL_ONE }

              it_behaves_like 'a created credential level'
            end
          end
        end
      end
    end
  end
end
