# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BGS::FlashUpdater, type: :job do
  subject { described_class }

  let(:user) { FactoryBot.create(:evss_user, :loa3) } # ssn 796043735
  let(:submission) { create(:form526_submission, :with_uploads, user_uuid: user.uuid) }
  let(:ssn) { submission.auth_headers['va_eauth_pnid'] }
  let(:flashes) { %w[Homeless POW] }
  let(:assigned_flashes) do
    { flashes: flashes.map { |flash| { assigned_indicator: nil, flash_name: "#{flash}    ", flash_type: nil } } }
  end

  it 'submits successfully with claim id' do
    expect do
      subject.perform_async(submission.id)
    end.to change(subject.jobs, :size).by(1)
  end

  it 'submits flashes to bgs successfully' do
    flashes.each do |flash_name|
      expect_any_instance_of(BGS::ClaimantWebService)
        .to receive(:add_flash).with(file_number: ssn, flash_name:)
    end
    expect_any_instance_of(BGS::ClaimantWebService)
      .to receive(:find_assigned_flashes).with(ssn).and_return(assigned_flashes)

    subject.new.perform(submission.id)
  end

  it 'continues submitting flashes on exception' do
    flashes.each_with_index do |flash_name, index|
      if index.zero?
        expect_any_instance_of(BGS::ClaimantWebService).to receive(:add_flash)
          .with(file_number: ssn, flash_name:).and_raise(BGS::ShareError.new('failed', 500))
      else
        expect_any_instance_of(BGS::ClaimantWebService)
          .to receive(:add_flash).with(file_number: ssn, flash_name:)
      end
    end
    expect_any_instance_of(BGS::ClaimantWebService)
      .to receive(:find_assigned_flashes).with(ssn).and_return(assigned_flashes)

    subject.new.perform(submission.id)
  end
end
