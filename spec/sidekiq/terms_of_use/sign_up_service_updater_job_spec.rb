# frozen_string_literal: true

require 'rails_helper'
require 'sidekiq/attr_package'

RSpec.describe TermsOfUse::SignUpServiceUpdaterJob, type: :job do
  before do
    Timecop.freeze(Time.zone.now)
    allow(MAP::SignUp::Service).to receive(:new).and_return(service_instance)
  end

  after do
    Timecop.return
  end

  describe '#perform' do
    subject(:job) { described_class.new }

    let(:user_account) { create(:user_account) }
    let(:user_account_uuid) { user_account.id }
    let(:icn) { user_account.icn }
    let(:terms_of_use_agreement) { create(:terms_of_use_agreement, user_account:, response:) }
    let(:response) { 'accepted' }
    let(:response_time) { terms_of_use_agreement.created_at.iso8601 }
    let(:given_names) { %w[given_name] }
    let(:family_name) { 'family_name' }
    let(:common_name) { "#{given_names.first} #{family_name}" }
    let(:sec_id) { 'some-sec-id' }
    let(:sec_ids) { [sec_id] }
    let(:service_instance) { instance_double(MAP::SignUp::Service) }
    let(:version) { terms_of_use_agreement&.agreement_version }
    let(:expires_in) { 72.hours }
    let(:find_profile_response) { create(:find_profile_response, profile: mpi_profile) }
    let(:mpi_profile) { build(:mpi_profile, icn:, sec_id:, sec_ids:, given_names:, family_name:) }
    let(:mpi_service) { instance_double(MPI::Service, find_profile_by_identifier: find_profile_response) }

    before do
      allow(MPI::Service).to receive(:new).and_return(mpi_service)
    end

    it 'retries for 47 hours after failure' do
      expect(described_class.get_sidekiq_options['retry_for']).to eq(48.hours)
    end

    context 'when retries have been exhausted' do
      let(:job) { { args: [user_account_uuid, version] }.as_json }
      let(:exception_message) { 'some-error' }
      let(:exception) { StandardError.new(exception_message) }
      let(:expected_log_message) { '[TermsOfUse][SignUpServiceUpdaterJob] retries exhausted' }

      before do
        allow(Rails.logger).to receive(:warn)
        Timecop.travel(47.hours.from_now)
      end

      context 'when the attr_package is found' do
        let(:expected_log_payload) do
          { icn:, response:, response_time:, version:, exception_message: }
        end

        it 'logs a warning message with the expected payload' do
          described_class.sidekiq_retries_exhausted_block.call(job, exception)

          expect(Rails.logger).to have_received(:warn).with(expected_log_message, expected_log_payload)
        end
      end

      context 'when the agreement is not found' do
        let(:terms_of_use_agreement) { nil }
        let(:expected_log_payload) do
          { icn:, response: nil, response_time: nil, version: nil, exception_message: }
        end

        it 'logs a warning message with the expected payload' do
          described_class.sidekiq_retries_exhausted_block.call(job, exception)

          expect(Rails.logger).to have_received(:warn).with(expected_log_message, expected_log_payload)
        end
      end
    end

    context 'when sec_id is present' do
      let(:status) { { opt_out: false, agreement_signed: false } }

      before do
        allow(service_instance).to receive(:agreements_accept)
        allow(service_instance).to receive(:status).and_return(status)
        allow(Rails.logger).to receive(:info)
      end

      shared_examples 'logs an unchanged agreement' do
        let(:expected_log) do
          '[TermsOfUse][SignUpServiceUpdaterJob] Not updating Sign Up Service due to unchanged agreement'
        end

        before do
          allow(Rails.logger).to receive(:info)
        end

        it 'logs that the agreement is not changed' do
          job.perform(user_account_uuid, version)

          expect(Rails.logger).to have_received(:info).with(expected_log, icn:)
        end
      end

      shared_examples 'logs an icn mismatch warning' do
        let(:expected_log) do
          '[TermsOfUse][SignUpServiceUpdaterJob] Detected changed ICN for user'
        end
        let(:mpi_profile) { build(:mpi_profile, icn: mpi_icn, sec_id:, given_names:, family_name:) }
        let(:mpi_icn) { 'some-mpi-icn' }

        before do
          allow(Rails.logger).to receive(:info)
        end

        it 'logs a detected changed ICN message' do
          job.perform(user_account_uuid, version)

          expect(MAP::SignUp::Service).to have_received(:new)
          expect(Rails.logger).to have_received(:info).with(expected_log, { icn:, mpi_icn: })
        end
      end

      context 'when multiple sec_id values are detected' do
        let(:sec_ids) { [sec_id, 'other-sec-id'] }

        let(:expected_log) { '[TermsOfUse][SignUpServiceUpdaterJob] Multiple sec_id values detected' }

        it 'logs a warning message' do
          job.perform(user_account_uuid, version)

          expect(Rails.logger).to have_received(:info).with(expected_log, icn:)
        end
      end

      context 'and terms of use agreement is accepted' do
        let(:response) { 'accepted' }

        before do
          allow(service_instance).to receive(:status).and_return(status)
          allow(service_instance).to receive(:agreements_accept)
        end

        context 'when sign up service status agreement response is true' do
          let(:status) { { opt_out: false, agreement_signed: true } }

          it_behaves_like 'logs an unchanged agreement'

          it 'does not update terms of use agreement in sign up service' do
            job.perform(user_account_uuid, version)

            expect(service_instance).not_to have_received(:agreements_accept)
          end
        end

        context 'when sign up service status agreement response is false' do
          let(:status) { { opt_out: false, agreement_signed: false } }

          it 'updates the terms of use agreement in sign up service' do
            job.perform(user_account_uuid, version)

            expect(service_instance).to have_received(:agreements_accept).with(icn: user_account.icn,
                                                                               signature_name: common_name,
                                                                               version:)
          end

          context 'and user account icn does not equal the mpi profile icn' do
            it_behaves_like 'logs an icn mismatch warning'
          end
        end
      end

      context 'and terms of use agreement is declined' do
        let(:response) { 'declined' }

        before do
          allow(service_instance).to receive(:status).and_return(status)
          allow(service_instance).to receive(:agreements_decline)
        end

        context 'when sign up service status opt out response is true' do
          let(:status) { { opt_out: true, agreement_signed: false } }

          it_behaves_like 'logs an unchanged agreement'

          it 'does not update terms of use agreement in sign up service' do
            job.perform(user_account_uuid, version)

            expect(service_instance).not_to have_received(:agreements_decline)
          end
        end

        context 'when sign up service status opt out response is false' do
          let(:status) { { opt_out: false, agreement_signed: false } }

          it 'updates the terms of use agreement in sign up service' do
            job.perform(user_account_uuid, version)

            expect(service_instance).to have_received(:agreements_decline).with(icn: user_account.icn)
          end

          context 'and user account icn does not equal the mpi profile icn' do
            it_behaves_like 'logs an icn mismatch warning'
          end
        end
      end
    end

    context 'when sec_id is not present' do
      let(:sec_id) { nil }
      let(:expected_log) do
        '[TermsOfUse][SignUpServiceUpdaterJob] Sign Up Service not updated due to user missing sec_id'
      end

      before do
        allow(Rails.logger).to receive(:info)
      end

      it 'does not update the terms of use agreement in sign up service and logs expected message' do
        job.perform(user_account_uuid, version)

        expect(MAP::SignUp::Service).not_to have_received(:new)
        expect(Rails.logger).to have_received(:info).with(expected_log, icn:)
      end
    end
  end
end
