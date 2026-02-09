# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SignIn::AcrTranslator do
  describe '#perform' do
    subject do
      SignIn::AcrTranslator.new(acr:, type:, uplevel:).perform
    end

    let(:acr) { 'some-acr' }
    let(:type) { 'some-type' }
    let(:uplevel) { false }

    context 'when type is idme' do
      let(:type) { SignIn::Constants::Auth::IDME }
      let(:ial2_feature_flag_enabled) { false }

      before do
        allow(Flipper).to receive(:enabled?).and_call_original
        allow(Flipper).to receive(:enabled?).with('identity_idme_ial2_enforcement')
                                            .and_return(ial2_feature_flag_enabled)
      end

      context 'and acr is loa1' do
        let(:acr) { 'loa1' }
        let(:expected_translated_acr) { { acr: SignIn::Constants::Auth::IDME_LOA1 } }

        it 'returns expected translated acr value' do
          expect(subject).to eq(expected_translated_acr)
        end
      end

      context 'and acr is loa3' do
        let(:acr) { 'loa3' }
        let(:expected_translated_acr) { { acr: SignIn::Constants::Auth::IDME_LOA3_FORCE } }

        it 'returns expected translated acr value' do
          expect(subject).to eq(expected_translated_acr)
        end
      end

      context 'and acr is IAL2_REQUIRED' do
        let(:acr) { SignIn::Constants::Auth::IAL2_REQUIRED }

        context 'when ial2 is enabled' do
          let(:ial2_feature_flag_enabled) { true }
          let(:expected_translated_acr) { { acr: SignIn::Constants::Auth::IDME_IAL2 } }

          it 'returns expected translated acr value' do
            expect(subject).to eq(expected_translated_acr)
          end
        end

        context 'when ial2 is disabled' do
          let(:ial2_feature_flag_enabled) { false }
          let(:expected_error) { SignIn::Errors::InvalidAcrError }
          let(:expected_error_message) { 'Invalid ACR for idme' }

          it 'raises invalid acr error' do
            expect { subject }.to raise_error(expected_error, expected_error_message)
          end
        end
      end

      context 'and acr is min' do
        let(:acr) { 'min' }

        context 'and uplevel is false' do
          let(:uplevel) { false }
          let(:acr_comparison) { SignIn::Constants::Auth::IDME_COMPARISON_MINIMUM }
          let(:expected_translated_acr) { { acr: SignIn::Constants::Auth::IDME_LOA1, acr_comparison: } }

          it 'returns expected translated acr value' do
            expect(subject).to eq(expected_translated_acr)
          end
        end

        context 'and uplevel is true' do
          let(:uplevel) { true }
          let(:expected_translated_acr) { { acr: SignIn::Constants::Auth::IDME_LOA3 } }

          it 'returns expected translated acr value' do
            expect(subject).to eq(expected_translated_acr)
          end
        end
      end

      context 'and acr is an arbitrary value' do
        let(:acr) { 'some-acr' }
        let(:expected_error) { SignIn::Errors::InvalidAcrError }
        let(:expected_error_message) { 'Invalid ACR for idme' }

        it 'raises invalid type error' do
          expect { subject }.to raise_error(expected_error, expected_error_message)
        end
      end
    end

    context 'when type is logingov' do
      let(:type) { SignIn::Constants::Auth::LOGINGOV }
      let(:ial2_feature_flag_enabled) { false }

      before do
        allow(Flipper).to receive(:enabled?).and_call_original
        allow(Flipper).to receive(:enabled?).with('identity_logingov_ial2_enforcement')
                                            .and_return(ial2_feature_flag_enabled)
      end

      context 'and acr is ial1' do
        let(:acr) { 'ial1' }
        let(:expected_translated_acr) { { acr: SignIn::Constants::Auth::LOGIN_GOV_IAL1 } }

        it 'returns expected translated acr value' do
          expect(subject).to eq(expected_translated_acr)
        end
      end

      context 'and acr is ial2' do
        let(:acr) { 'ial2' }
        let(:expected_translated_acr) { { acr: SignIn::Constants::Auth::LOGIN_GOV_IAL2 } }

        it 'returns expected translated acr value' do
          expect(subject).to eq(expected_translated_acr)
        end
      end

      context 'and acr is IAL2_REQUIRED' do
        let(:acr) { SignIn::Constants::Auth::IAL2_REQUIRED }

        context 'when ial2 is enabled' do
          let(:ial2_feature_flag_enabled) { true }
          let(:expected_translated_acr) { { acr: SignIn::Constants::Auth::LOGIN_GOV_IAL2_REQUIRED } }

          it 'returns expected translated acr value' do
            expect(subject).to eq(expected_translated_acr)
          end
        end

        context 'when ial2 is disabled' do
          let(:ial2_feature_flag_enabled) { false }
          let(:expected_error) { SignIn::Errors::InvalidAcrError }
          let(:expected_error_message) { 'Invalid ACR for logingov' }

          it 'raises invalid acr error' do
            expect { subject }.to raise_error(expected_error, expected_error_message)
          end
        end
      end

      context 'and acr is IAL2_PREFERRED' do
        let(:acr) { SignIn::Constants::Auth::IAL2_PREFERRED }

        context 'when ial2 is enabled' do
          let(:ial2_feature_flag_enabled) { true }
          let(:expected_translated_acr) { { acr: SignIn::Constants::Auth::LOGIN_GOV_IAL2_PREFERRED } }

          it 'returns expected translated acr value' do
            expect(subject).to eq(expected_translated_acr)
          end
        end

        context 'when ial2 is disabled' do
          let(:ial2_feature_flag_enabled) { false }
          let(:expected_error) { SignIn::Errors::InvalidAcrError }
          let(:expected_error_message) { 'Invalid ACR for logingov' }

          it 'raises invalid acr error' do
            expect { subject }.to raise_error(expected_error, expected_error_message)
          end
        end
      end

      context 'and acr is min' do
        let(:acr) { 'min' }

        context 'and uplevel is false' do
          let(:uplevel) { false }
          let(:expected_translated_acr) { { acr: SignIn::Constants::Auth::LOGIN_GOV_IAL0 } }

          it 'returns expected translated acr value' do
            expect(subject).to eq(expected_translated_acr)
          end
        end

        context 'and uplevel is true' do
          let(:uplevel) { true }

          let(:ial2_feature_flag_enabled) { false }
          let(:expected_translated_acr) { { acr: SignIn::Constants::Auth::LOGIN_GOV_IAL2 } }

          it 'returns expected translated acr value' do
            expect(subject).to eq(expected_translated_acr)
          end
        end
      end

      context 'and acr is an arbitrary value' do
        let(:acr) { 'some-acr' }
        let(:expected_error) { SignIn::Errors::InvalidAcrError }
        let(:expected_error_message) { 'Invalid ACR for logingov' }

        it 'raises invalid type error' do
          expect { subject }.to raise_error(expected_error, expected_error_message)
        end
      end
    end

    context 'when type is mhv' do
      let(:type) { SignIn::Constants::Auth::MHV }

      context 'and acr is loa1' do
        let(:acr) { 'loa1' }
        let(:expected_translated_acr) { { acr: SignIn::Constants::Auth::IDME_MHV_LOA1 } }

        it 'returns expected translated acr value' do
          expect(subject).to eq(expected_translated_acr)
        end
      end

      context 'and acr is loa3' do
        let(:acr) { 'loa3' }
        let(:expected_translated_acr) { { acr: SignIn::Constants::Auth::IDME_MHV_LOA1 } }

        it 'returns expected translated acr value' do
          expect(subject).to eq(expected_translated_acr)
        end
      end

      context 'and acr is min' do
        let(:acr) { 'min' }
        let(:expected_translated_acr) { { acr: SignIn::Constants::Auth::IDME_MHV_LOA1 } }

        it 'returns expected translated acr value' do
          expect(subject).to eq(expected_translated_acr)
        end
      end

      context 'and acr is an arbitrary value' do
        let(:acr) { 'some-acr' }
        let(:expected_error) { SignIn::Errors::InvalidAcrError }
        let(:expected_error_message) { 'Invalid ACR for mhv' }

        it 'raises invalid type error' do
          expect { subject }.to raise_error(expected_error, expected_error_message)
        end
      end
    end

    context 'when type is an arbitrary value' do
      let(:type) { 'some-type' }
      let(:expected_error) { SignIn::Errors::InvalidTypeError }
      let(:expected_error_message) { 'Invalid Type value' }

      it 'raises invalid type error' do
        expect { subject }.to raise_error(expected_error, expected_error_message)
      end
    end
  end
end
