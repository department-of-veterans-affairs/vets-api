# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TermsOfUse::Acceptor, type: :service do
  describe '#perform!' do
    subject(:acceptor) { described_class.new(user_account:, version:) }

    let(:user_account) { create(:user_account, icn:) }
    let(:icn) { '123456789' }
    let(:version) { 'v1' }

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
      let(:expected_attr_key) { SecureRandom.hex(32) }
      let(:sign_up_service_updater_job) { TermsOfUse::SignUpServiceUpdaterJob.set(sync:) }
      let(:find_profile_response) { create(:find_profile_response, profile: mpi_profile) }
      let(:mpi_profile) { build(:mpi_profile, icn:, sec_id:) }
      let(:sec_id) { 'some-sec-id' }

      before do
        allow(SecureRandom).to receive(:hex).and_return(expected_attr_key)
        allow(Rails.logger).to receive(:info)
        allow(TermsOfUse::SignUpServiceUpdaterJob).to receive(:set).and_return(sign_up_service_updater_job)
        allow(sign_up_service_updater_job).to receive(:perform_async)
        allow_any_instance_of(MPI::Service).to receive(:find_profile_by_identifier).and_return(find_profile_response)
      end

      context 'when sync is false' do
        let(:sync) { false }

        it 'creates a new terms of use agreement with the given version' do
          expect { acceptor.perform! }.to change { user_account.terms_of_use_agreements.count }.by(1)
          expect(user_account.terms_of_use_agreements.last.agreement_version).to eq(version)
        end

        it 'marks the terms of use agreement as accepted' do
          expect(acceptor.perform!).to be_accepted
        end

        context 'and sec_id exists for the user' do
          let(:sec_id) { 'some-sec-id' }

          it 'enqueues the SignUpServiceUpdaterJob with expected parameters' do
            acceptor.perform!
            expect(TermsOfUse::SignUpServiceUpdaterJob).to have_received(:set).with(sync: false)
            expect(sign_up_service_updater_job).to have_received(:perform_async).with(expected_attr_key)
          end

          it 'logs the attr_package key' do
            acceptor.perform!
            expect(Rails.logger).to have_received(:info).with('[TermsOfUse] [Acceptor] attr_package key',
                                                              { icn:, attr_package_key: expected_attr_key })
          end
        end

        context 'and sec_id does not exist for the user' do
          let(:sec_id) { nil }
          let(:expected_log) { '[TermsOfUse] [Acceptor] Sign Up Service not updated due to user missing sec_id' }

          it 'does not enqueue the SignUpServiceUpdaterJob' do
            acceptor.perform!
            expect(TermsOfUse::SignUpServiceUpdaterJob).not_to have_received(:set)
          end

          it 'logs a sign up service not updated message' do
            acceptor.perform!
            expect(Rails.logger).to have_received(:info).with(expected_log, { icn: })
          end
        end
      end

      context 'when sync is true' do
        subject(:acceptor) { described_class.new(user_account:, version:, sync: true) }

        let(:sync) { true }

        context 'and sec_id exists for the user' do
          let(:sec_id) { 'some-sec-id' }

          it 'calls the SignUpServiceUpdaterJob with expected parameters' do
            acceptor.perform!
            expect(TermsOfUse::SignUpServiceUpdaterJob).to have_received(:set).with(sync: true)
            expect(sign_up_service_updater_job).to have_received(:perform_async).with(expected_attr_key)
          end

          it 'logs the attr_package key' do
            acceptor.perform!
            expect(Rails.logger).to have_received(:info).with('[TermsOfUse] [Acceptor] attr_package key',
                                                              { icn:, attr_package_key: expected_attr_key })
          end
        end

        context 'and sec_id does not exist for the user' do
          let(:sec_id) { nil }
          let(:expected_log) { '[TermsOfUse] [Acceptor] Sign Up Service not updated due to user missing sec_id' }

          it 'does not enqueue the SignUpServiceUpdaterJob' do
            acceptor.perform!
            expect(TermsOfUse::SignUpServiceUpdaterJob).not_to have_received(:set)
          end

          it 'logs a sign up service not updated message' do
            acceptor.perform!
            expect(Rails.logger).to have_received(:info).with(expected_log, { icn: })
          end
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
            allow(sign_up_service_updater_job).to receive(:perform_async).and_raise(StandardError)
          end

          it 'raises an AcceptorError' do
            expect { acceptor.perform! }.to raise_error(TermsOfUse::Errors::AcceptorError)
          end
        end
      end
    end
  end
end
