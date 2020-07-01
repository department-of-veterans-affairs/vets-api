# frozen_string_literal: true

require 'rails_helper'
require 'sidekiq/testing'
Sidekiq::Testing.fake!

RSpec.describe VAOS::ExtendSessionJob, type: :job do
  subject { described_class }

  let(:user) { build(:user, :vaos, :accountable) }

  before do
    Sidekiq::Worker.clear_all
  end

  describe '.perform_async' do
    it 'submits succesfully' do
      expect do
        subject.perform_async(user.account_uuid)
      end.to change(subject.jobs, :size).by(1)
    end

    it 'calls user service update_session_token with the user account uuid' do
      expect_any_instance_of(VAOS::UserService).to receive(:update_session_token).with(user.account_uuid)
      subject.new.perform(user.account_uuid)
    end
  end
end
