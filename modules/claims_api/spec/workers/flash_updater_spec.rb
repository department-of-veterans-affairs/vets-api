# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ClaimsApi::FlashUpdater, type: :job do
  subject { described_class }

  before do
    Sidekiq::Worker.clear_all
  end

  let(:user) do
    user_mock = FactoryBot.create(:evss_user, :loa3)
    {
      'ssn' => user_mock.ssn
    }
  end
  let(:flashes) { %w[Homeless POW] }
  let(:claim) { create(:auto_established_claim) }
  let(:assigned_flashes) do
    { flashes: flashes.map { |flash| { assigned_indicator: nil, flash_name: "#{flash}    ", flash_type: nil } } }
  end

  it 'submits successfully without claim id' do
    expect do
      subject.perform_async(user, flashes)
    end.to change(subject.jobs, :size).by(1)
  end

  it 'submits successfully with claim id' do
    expect do
      subject.perform_async(user, flashes, auto_claim_id: claim.id)
    end.to change(subject.jobs, :size).by(1)
  end

  it 'submits flashes to bgs successfully' do
    flashes.each do |flash_name|
      expect_any_instance_of(BGS::ClaimantWebService)
        .to receive(:add_flash).with(file_number: user['ssn'], flash_name: flash_name)
    end
    expect_any_instance_of(BGS::ClaimantWebService)
      .to receive(:find_assigned_flashes).with(user['ssn']).and_return(assigned_flashes)

    subject.new.perform(user, flashes)
  end

  it 'continues submitting flashes on exception' do
    flashes.each_with_index do |flash_name, index|
      if index.zero?
        expect_any_instance_of(BGS::ClaimantWebService).to receive(:add_flash)
          .with(file_number: user['ssn'], flash_name: flash_name).and_raise(BGS::ShareError.new('failed', 500))
      else
        expect_any_instance_of(BGS::ClaimantWebService)
          .to receive(:add_flash).with(file_number: user['ssn'], flash_name: flash_name)
      end
    end
    expect_any_instance_of(BGS::ClaimantWebService)
      .to receive(:find_assigned_flashes).with(user['ssn']).and_return(assigned_flashes)

    subject.new.perform(user, flashes, claim.id)
  end

  it 'stores multiple bgs exceptions correctly' do
    flashes.each do |flash_name|
      expect_any_instance_of(BGS::ClaimantWebService).to receive(:add_flash)
        .with(file_number: user['ssn'], flash_name: flash_name).and_raise(BGS::ShareError.new('failed', 500))
    end
    expect_any_instance_of(BGS::ClaimantWebService)
      .to receive(:find_assigned_flashes).with(user['ssn']).and_return({ flashes: [] })

    subject.new.perform(user, flashes, claim.id)
    expect(ClaimsApi::AutoEstablishedClaim.find(claim.id).bgs_flash_responses.count).to eq(flashes.count * 2)
  end
end
