# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ClaimsApi::FlashUpdater, type: :job do
  subject { described_class }

  before do
    Sidekiq::Job.clear_all
  end

  let(:user) do
    user_mock = create(:evss_user, :loa3)
    {
      'ssn' => user_mock.ssn
    }
  end
  let(:flashes) { %w[Hardship Homeless] }
  let(:claim) { create(:auto_established_claim, :with_full_headers) }
  let(:assigned_flashes) do
    { flashes: flashes.map do |flash|
                 { assigned_indicator: claim.auth_headers['va_eauth_pnid'], flash_name: "#{flash}    ",
                   flash_type: nil }
               end }
  end

  it 'submits successfully without claim id' do
    expect do
      subject.perform_async(flashes)
    end.to change(subject.jobs, :size).by(1)
  end

  it 'submits successfully with claim id' do
    expect do
      subject.perform_async(flashes, auto_claim_id: claim.id)
    end.to change(subject.jobs, :size).by(1)
  end

  it 'submits flashes to bgs successfully' do
    flashes.each do |flash_name|
      allow_any_instance_of(ClaimsApi::ClaimantWebService)
        .to receive(:add_flash).with(file_number: claim.auth_headers['va_eauth_pnid'], flash: { flash_name: })
    end
    expect_any_instance_of(ClaimsApi::ClaimantWebService)
      .to receive(:find_assigned_flashes).with(claim.auth_headers['va_eauth_pnid']).and_return(assigned_flashes)

    subject.new.perform(flashes, claim.id)
  end

  it 'continues submitting flashes on exception' do
    flashes.each_with_index do |flash_name, index|
      if index.zero?
        allow_any_instance_of(ClaimsApi::ClaimantWebService).to receive(:add_flash)
          .with(file_number: claim.auth_headers['va_eauth_pnid'], flash: { flash_name: })
          .and_raise(BGS::ShareError.new('failed', 500))
      else
        allow_any_instance_of(ClaimsApi::ClaimantWebService)
          .to receive(:add_flash).with(file_number: claim.auth_headers['va_eauth_pnid'], flash: { flash_name: })
      end
    end
    expect_any_instance_of(ClaimsApi::ClaimantWebService)
      .to receive(:find_assigned_flashes).with(claim.auth_headers['va_eauth_pnid']).and_return(assigned_flashes)

    subject.new.perform(flashes, claim.id)
  end

  it 'stores multiple bgs exceptions correctly' do
    flashes.each do |flash_name|
      allow_any_instance_of(ClaimsApi::ClaimantWebService).to receive(:add_flash)
        .with(file_number: claim.auth_headers['va_eauth_pnid'], flash: { flash_name: })
        .and_raise(BGS::ShareError.new('failed', 500))
    end
    expect_any_instance_of(ClaimsApi::ClaimantWebService)
      .to receive(:find_assigned_flashes).with(claim.auth_headers['va_eauth_pnid']).and_return({ flashes: [] })

    subject.new.perform(flashes, claim.id)
    expect(ClaimsApi::AutoEstablishedClaim.find(claim.id).bgs_flash_responses.count).to eq(flashes.count * 2)
  end

  describe 'when an errored job has exhausted its retries' do
    it 'logs to the ClaimsApi Logger' do
      error_msg = 'An error occurred from the Flash Updater Job'
      msg = { 'args' => ['value here', claim.id],
              'class' => subject,
              'error_message' => error_msg }

      described_class.within_sidekiq_retries_exhausted_block(msg) do
        expect(ClaimsApi::Logger).to receive(:log).with(
          'claims_api_retries_exhausted',
          claim_id: claim.id,
          detail: "Job retries exhausted for #{subject}",
          error: error_msg
        )
      end
    end
  end
end
