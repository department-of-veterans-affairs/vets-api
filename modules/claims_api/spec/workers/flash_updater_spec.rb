# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ClaimsApi::FlashUpdater, type: :job do
  subject { described_class }

  before do
    Sidekiq::Worker.clear_all
  end

  let(:user) { FactoryBot.create(:evss_user, :loa3) }
  let(:flashes) { %w[Homeless POW] }

  it 'submits succesfully' do
    expect do
      subject.perform_async(user, flashes)
    end.to change(subject.jobs, :size).by(1)
  end

  it 'submits flashes to bgs successfully' do
    flashes.each do |flash_name|
      expect_any_instance_of(BGS::ClaimantWebService)
        .to receive(:add_flash).with(file_number: user.ssn, flash_name: flash_name)
    end

    subject.new.perform(user, flashes)
  end

  it 'continues submitting flashes on exception' do
    flashes.each_with_index do |flash_name, index|
      if index.zero?
        expect_any_instance_of(BGS::ClaimantWebService).to receive(:add_flash)
          .with(file_number: user.ssn, flash_name: flash_name).and_raise(BGS::ShareError.new('failed', 500))
      else
        expect_any_instance_of(BGS::ClaimantWebService)
          .to receive(:add_flash).with(file_number: user.ssn, flash_name: flash_name)
      end
    end

    subject.new.perform(user, flashes)
  end
end
