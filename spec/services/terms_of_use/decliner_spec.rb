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
      let(:expected_attr_key) { SecureRandom.hex(32) }
      let(:find_profile_response) { create(:find_profile_response, profile: mpi_profile) }
      let(:mpi_profile) { build(:mpi_profile, icn:, sec_id:) }
      let(:sec_id) { 'some-sec-id' }

      before do
        allow(TermsOfUse::SignUpServiceUpdaterJob).to receive(:perform_async)
        allow(SecureRandom).to receive(:hex).and_return(expected_attr_key)
        allow(Rails.logger).to receive(:info)
        allow_any_instance_of(MPI::Service).to receive(:find_profile_by_identifier).and_return(find_profile_response)
      end

      it 'creates a new terms of use agreement with the given version' do
        expect { decliner.perform! }.to change { user_account.terms_of_use_agreements.count }.by(1)
        expect(user_account.terms_of_use_agreements.last.agreement_version).to eq(version)
      end

      it 'marks the terms of use agreement as declined' do
        expect(decliner.perform!).to be_declined
      end

      context 'and sec_id exists for the user' do
        let(:sec_id) { 'some-sec-id' }

        it 'enqueues the SignUpServiceUpdaterJob with expected parameters' do
          decliner.perform!
          expect(TermsOfUse::SignUpServiceUpdaterJob).to have_received(:perform_async).with(expected_attr_key)
        end

        it 'logs the attr_package key' do
          decliner.perform!
          expect(Rails.logger).to have_received(:info).with('[TermsOfUse] [Decliner] attr_package key',
                                                            { icn:, attr_package_key: expected_attr_key })
        end
      end

      context 'and sec_id does not exist for the user' do
        let(:sec_id) { nil }
        let(:expected_log) { '[TermsOfUse] [Decliner] Sign Up Service not updated due to user missing sec_id' }

        it 'does not enqueue the SignUpServiceUpdaterJob' do
          decliner.perform!
          expect(TermsOfUse::SignUpServiceUpdaterJob).not_to have_received(:perform_async)
        end

        it 'logs a sign up service not updated message' do
          decliner.perform!
          expect(Rails.logger).to have_received(:info).with(expected_log, { icn: })
        end
      end
    end
  end
end
