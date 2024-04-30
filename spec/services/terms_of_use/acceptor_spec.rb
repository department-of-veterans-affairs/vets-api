# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TermsOfUse::Acceptor, type: :service do
  describe '#perform!' do
    subject(:acceptor) { described_class.new(user_account:, common_name:, version:) }

    let(:user_account) { create(:user_account, icn:) }
    let(:icn) { '123456789' }
    let(:version) { 'v1' }
    let(:common_name) { 'some-common-name' }

    describe 'validations' do
      context 'when all attributes are present' do
        it 'is valid' do
          expect(acceptor).to be_valid
        end
      end

      context 'when attributes are missing' do
        before do
          allow(Rails.logger).to receive(:error)
        end

        let(:expected_log) do
          "[TermsOfUse] [Acceptor] Error: #{expected_error_message}"
        end

        context 'when user_account is missing' do
          let(:user_account) { nil }
          let(:expected_error_message) { 'Validation failed: User account can\'t be blank, Icn can\'t be blank' }

          it 'is not valid' do
            expect { acceptor }.to raise_error(TermsOfUse::Errors::AcceptorError).with_message(expected_error_message)
            expect(Rails.logger).to have_received(:error).with(expected_log, { user_account_id: nil })
          end
        end

        context 'when common_name is missing' do
          let(:common_name) { nil }
          let(:expected_error_message) { 'Validation failed: Common name can\'t be blank' }

          it 'is not valid' do
            expect { acceptor }.to raise_error(TermsOfUse::Errors::AcceptorError).with_message(expected_error_message)
            expect(Rails.logger).to have_received(:error).with(expected_log, { user_account_id: user_account.id })
          end
        end

        context 'when version is missing' do
          let(:version) { nil }
          let(:expected_error_message) { 'Validation failed: Version can\'t be blank' }

          it 'is not valid' do
            expect { acceptor }.to raise_error(TermsOfUse::Errors::AcceptorError).with_message(expected_error_message)
            expect(Rails.logger).to have_received(:error).with(expected_log, { user_account_id: user_account.id })
          end
        end

        context 'when icn is missing' do
          let(:icn) { nil }
          let(:expected_error_message) { 'Validation failed: Icn can\'t be blank' }

          it 'is not valid' do
            expect { acceptor }.to raise_error(TermsOfUse::Errors::AcceptorError).with_message(expected_error_message)
            expect(Rails.logger).to have_received(:error).with(expected_log, { user_account_id: user_account.id })
          end
        end
      end
    end

    describe '#perform!' do
      let(:expected_attr_key) do
        Digest::SHA256.hexdigest({ icn:, signature_name: common_name, version: }.to_json)
      end

      context 'when async is true' do
        before do
          allow(TermsOfUse::SignUpServiceUpdaterJob).to receive(:perform_async)
        end

        it 'creates a new terms of use agreement with the given version' do
          expect { acceptor.perform! }.to change { user_account.terms_of_use_agreements.count }.by(1)
          expect(user_account.terms_of_use_agreements.last.agreement_version).to eq(version)
        end

        it 'marks the terms of use agreement as accepted' do
          expect(acceptor.perform!).to be_accepted
        end

        it 'enqueues the SignUpServiceUpdaterJob with expected parameters' do
          acceptor.perform!
          expect(TermsOfUse::SignUpServiceUpdaterJob).to have_received(:perform_async).with(expected_attr_key)
        end
      end

      context 'when async is false' do
        subject(:acceptor) { described_class.new(user_account:, common_name:, version:, async: false) }

        let(:sign_up_service_updater_job) { instance_double(TermsOfUse::SignUpServiceUpdaterJob, perform: nil) }

        before do
          allow(TermsOfUse::SignUpServiceUpdaterJob).to receive(:new).and_return(sign_up_service_updater_job)
          allow(sign_up_service_updater_job).to receive(:perform).with(expected_attr_key)
        end

        it 'calls the SignUpServiceUpdaterJob with expected parameters' do
          acceptor.perform!
          expect(sign_up_service_updater_job).to have_received(:perform).with(expected_attr_key)
        end

        it 'creates a new terms of use agreement with the given version' do
          expect { acceptor.perform! }.to change { user_account.terms_of_use_agreements.count }.by(1)
          expect(user_account.terms_of_use_agreements.last.agreement_version).to eq(version)
        end

        it 'marks the terms of use agreement as accepted' do
          expect(acceptor.perform!).to be_accepted
        end

        context 'when the SignUpServiceUpdaterJob raises an error' do
          before do
            allow(TermsOfUse::SignUpServiceUpdaterJob).to receive(:new).and_raise(StandardError)
          end

          it 'raises an AcceptorError' do
            expect { acceptor.perform! }.to raise_error(TermsOfUse::Errors::AcceptorError)
          end
        end
      end
    end
  end
end
