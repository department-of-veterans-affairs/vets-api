# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TermsOfUse::Decliner, type: :service do
  describe '#perform!' do
    subject(:decliner) { described_class.new(user_account:, version:) }

    let(:user_account) { create(:user_account, icn:) }
    let(:icn) { '123456789' }
    let(:version) { 'v1' }

    describe 'validations' do
      context 'when all attributes are present' do
        it 'is valid' do
          expect(decliner).to be_valid
        end
      end

      context 'when attributes are missing' do
        before do
          allow(Rails.logger).to receive(:error)
        end

        let(:expected_log) do
          "[TermsOfUse] [Decliner] Error: #{expected_error_message}"
        end

        context 'when user_account is missing' do
          let(:user_account) { nil }
          let(:expected_error_message) { 'Validation failed: User account can\'t be blank, Icn can\'t be blank' }

          it 'is not valid' do
            expect { decliner }.to raise_error(TermsOfUse::Errors::DeclinerError).with_message(expected_error_message)
            expect(Rails.logger).to have_received(:error).with(expected_log, { user_account_id: nil })
          end
        end

        context 'when version is missing' do
          let(:version) { nil }
          let(:expected_error_message) { 'Validation failed: Version can\'t be blank' }

          it 'is not valid' do
            expect { decliner }.to raise_error(TermsOfUse::Errors::DeclinerError).with_message(expected_error_message)
            expect(Rails.logger).to have_received(:error).with(expected_log, { user_account_id: user_account.id })
          end
        end

        context 'when icn is missing' do
          let(:icn) { nil }
          let(:expected_error_message) { 'Validation failed: Icn can\'t be blank' }

          it 'is not valid' do
            expect { decliner }.to raise_error(TermsOfUse::Errors::DeclinerError).with_message(expected_error_message)
            expect(Rails.logger).to have_received(:error).with(expected_log, { user_account_id: user_account.id })
          end
        end
      end
    end

    describe '#perform!' do
      before do
        allow(TermsOfUse::SignUpServiceUpdaterJob).to receive(:perform_async)
        allow(Rails.logger).to receive(:info)
      end

      it 'creates a new terms of use agreement with the given version' do
        expect { decliner.perform! }.to change { user_account.terms_of_use_agreements.count }.by(1)
        expect(user_account.terms_of_use_agreements.last.agreement_version).to eq(version)
      end

      it 'marks the terms of use agreement as declined' do
        expect(decliner.perform!).to be_declined
      end

      it 'enqueues the SignUpServiceUpdaterJob with expected parameters' do
        decliner.perform!
        expect(TermsOfUse::SignUpServiceUpdaterJob).to have_received(:perform_async).with(user_account.id, version)
      end

      it 'logs the update_sign_up_service' do
        decliner.perform!
        expect(Rails.logger).to have_received(:info).with('[TermsOfUse] [Decliner] update_sign_up_service',
                                                          { icn: })
      end
    end
  end
end
