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
    let(:service_instance) { instance_double(MAP::SignUp::Service) }
    let(:version) { terms_of_use_agreement&.agreement_version }
    let(:expires_in) { 72.hours }
    let(:find_profile_response) { create(:find_profile_response, profile: mpi_profile) }
    let(:mpi_profile) { build(:mpi_profile, icn:, sec_id:, given_names:, family_name:) }
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
      context 'when the terms of use agreement is accepted' do
        before do
          allow(service_instance).to receive(:agreements_accept)
        end

        it 'updates the terms of use agreement in sign up service' do
          job.perform(user_account_uuid, version)

          expect(MAP::SignUp::Service).to have_received(:new)
          expect(service_instance).to have_received(:agreements_accept).with(icn: user_account.icn,
                                                                             signature_name: common_name,
                                                                             version:)
        end
      end

      context 'when the terms of use agreement is declined' do
        let(:response) { 'declined' }

        before do
          allow(service_instance).to receive(:agreements_decline)
        end

        it 'updates the terms of use agreement in sign up service' do
          job.perform(user_account_uuid, version)

          expect(MAP::SignUp::Service).to have_received(:new)
          expect(service_instance).to have_received(:agreements_decline).with(icn: user_account.icn)
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
