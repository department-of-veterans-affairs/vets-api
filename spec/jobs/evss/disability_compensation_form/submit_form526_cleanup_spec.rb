# frozen_string_literal: true

require 'rails_helper'
require 'sidekiq/testing'
Sidekiq::Testing.fake!

RSpec.describe EVSS::DisabilityCompensationForm::SubmitForm526Cleanup, type: :job do
  before(:each) do
    Sidekiq::Worker.clear_all
  end

  let(:user) { FactoryBot.create(:user, :loa3) }

  subject { described_class }

  describe '.perform_async' do
    let(:strategy_class) { EVSS::IntentToFile::ResponseStrategy }
    let(:strategy) { EVSS::IntentToFile::ResponseStrategy.new }

    context 'with a successful call' do
      it 'deletes the in progress form' do
        create(:in_progress_form, user_uuid: user.uuid, form_id: '21-526EZ')
        subject.perform_async(user.uuid)
        expect { described_class.drain }.to change { InProgressForm.count }.by(-1)
      end

      it 'deletes the cached ITF' do
        strategy.cache("#{user.uuid}:compensation", {})
        subject.perform_async(user.uuid)
        described_class.drain
        expect(strategy_class.find("#{user.uuid}:compensation")).to equal nil
      end
    end
  end
end
