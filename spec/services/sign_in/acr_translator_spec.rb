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

      context 'and acr is loa1' do
        let(:acr) { 'loa1' }
        let(:expected_translated_acr) { SignIn::Constants::Auth::IDME_LOA1 }

        it 'returns expected translated acr value' do
          expect(subject).to be(expected_translated_acr)
        end
      end

      context 'and acr is loa3' do
        let(:acr) { 'loa3' }
        let(:expected_translated_acr) { SignIn::Constants::Auth::IDME_LOA3_FORCE }

        it 'returns expected translated acr value' do
          expect(subject).to be(expected_translated_acr)
        end
      end

      context 'and acr is min' do
        let(:acr) { 'min' }

        context 'and uplevel is false' do
          let(:uplevel) { false }
          let(:expected_translated_acr) { SignIn::Constants::Auth::IDME_LOA1 }

          it 'returns expected translated acr value' do
            expect(subject).to be(expected_translated_acr)
          end
        end

        context 'and uplevel is true' do
          let(:uplevel) { true }
          let(:expected_translated_acr) { SignIn::Constants::Auth::IDME_LOA3 }

          it 'returns expected translated acr value' do
            expect(subject).to be(expected_translated_acr)
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

      context 'and acr is ial1' do
        let(:acr) { 'ial1' }
        let(:expected_translated_acr) { SignIn::Constants::Auth::LOGIN_GOV_IAL1 }

        it 'returns expected translated acr value' do
          expect(subject).to be(expected_translated_acr)
        end
      end

      context 'and acr is ial2' do
        let(:acr) { 'ial2' }
        let(:expected_translated_acr) { SignIn::Constants::Auth::LOGIN_GOV_IAL2 }

        it 'returns expected translated acr value' do
          expect(subject).to be(expected_translated_acr)
        end
      end

      context 'and acr is min' do
        let(:acr) { 'min' }

        context 'and uplevel is false' do
          let(:uplevel) { false }
          let(:expected_translated_acr) { SignIn::Constants::Auth::LOGIN_GOV_IAL1 }

          it 'returns expected translated acr value' do
            expect(subject).to be(expected_translated_acr)
          end
        end

        context 'and uplevel is true' do
          let(:uplevel) { true }
          let(:expected_translated_acr) { SignIn::Constants::Auth::LOGIN_GOV_IAL2 }

          it 'returns expected translated acr value' do
            expect(subject).to be(expected_translated_acr)
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

    context 'when type is dslogon' do
      let(:type) { SignIn::Constants::Auth::DSLOGON }

      context 'and acr is loa1' do
        let(:acr) { 'loa1' }
        let(:expected_translated_acr) { SignIn::Constants::Auth::IDME_DSLOGON_LOA1 }

        it 'returns expected translated acr value' do
          expect(subject).to be(expected_translated_acr)
        end
      end

      context 'and acr is loa3' do
        let(:acr) { 'loa3' }
        let(:expected_translated_acr) { SignIn::Constants::Auth::IDME_DSLOGON_LOA1 }

        it 'returns expected translated acr value' do
          expect(subject).to be(expected_translated_acr)
        end
      end

      context 'and acr is min' do
        let(:acr) { 'min' }

        let(:expected_translated_acr) { SignIn::Constants::Auth::IDME_DSLOGON_LOA1 }

        it 'returns expected translated acr value' do
          expect(subject).to be(expected_translated_acr)
        end
      end

      context 'and acr is an arbitrary value' do
        let(:acr) { 'some-acr' }
        let(:expected_error) { SignIn::Errors::InvalidAcrError }
        let(:expected_error_message) { 'Invalid ACR for dslogon' }

        it 'raises invalid type error' do
          expect { subject }.to raise_error(expected_error, expected_error_message)
        end
      end
    end

    context 'when type is mhv' do
      let(:type) { SignIn::Constants::Auth::MHV }

      context 'and acr is loa1' do
        let(:acr) { 'loa1' }
        let(:expected_translated_acr) { SignIn::Constants::Auth::IDME_MHV_LOA1 }

        it 'returns expected translated acr value' do
          expect(subject).to be(expected_translated_acr)
        end
      end

      context 'and acr is loa3' do
        let(:acr) { 'loa3' }
        let(:expected_translated_acr) { SignIn::Constants::Auth::IDME_MHV_LOA1 }

        it 'returns expected translated acr value' do
          expect(subject).to be(expected_translated_acr)
        end
      end

      context 'and acr is min' do
        let(:acr) { 'min' }
        let(:expected_translated_acr) { SignIn::Constants::Auth::IDME_MHV_LOA1 }

        it 'returns expected translated acr value' do
          expect(subject).to be(expected_translated_acr)
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
