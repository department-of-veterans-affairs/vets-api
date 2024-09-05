# frozen_string_literal: true

require 'rails_helper'
require 'lighthouse/benefits_claims/service'

RSpec.describe Lighthouse::CreateIntentToFileJob do
  let(:job) { described_class.new }
  let(:user) { create(:user) }
  let!(:user_verification) { create(:idme_user_verification, idme_uuid: user.idme_uuid) }
  let(:user_account) { create(:user_account, icn: user.icn, user_verifications: [user_verification]) }
  let(:pension_ipf) { create(:in_progress_527_form, user_account:) }
  let(:service) { double('service') }
  let(:monitor) { double('monitor') }

  describe '#perform' do
    let(:response) { double('response') }

    before do
      job.instance_variable_set(:@user_account, user_account)
      job.instance_variable_set(:@itf_type, 'pension')
      allow(InProgressForm).to receive(:find).and_return(pension_ipf)

      job.instance_variable_set(:@service, service)
      allow(BenefitsClaims::Service).to receive(:new).and_return(service)
      allow(service).to receive(:create_intent_to_file).and_return(response)

      job.instance_variable_set(:@itf_log_monitor, monitor)
      allow(monitor).to receive :track_create_itf_begun
      allow(monitor).to receive :track_create_itf_failure
      allow(monitor).to receive :track_create_itf_success
      allow(monitor).to receive :track_create_itf_exhaustion
      allow(monitor).to receive :track_create_itf_exhaustion_failure
      allow(monitor).to receive :track_missing_user_icn
      allow(monitor).to receive :track_missing_user_pid
    end

    # Retries exhausted
    describe 'sidekiq_retries_exhausted block' do
      context 'when retries are exhausted' do
        it 'logs a distinct error when form_type, form_start_date, and veteran_icn provided' do
          Lighthouse::CreateIntentToFileJob.within_sidekiq_retries_exhausted_block(
            { 'args' => ['21P-527EZ', pension_ipf.created_at.to_s, user_account.icn] }
          ) do
            expect(Rails.logger).to receive(:error).exactly(:once).with(
              'Lighthouse::CreateIntentToFileJob create pension ITF exhausted',
              hash_including(:error, itf_type: 'pension',
                                     form_start_date: pension_ipf.created_at.to_s,
                                     user_account_uuid: user_account.id)
            )
            expect(StatsD).to receive(:increment).with('worker.lighthouse.create_itf_async.exhausted')
          end
        end
      end
    end
  end
end
