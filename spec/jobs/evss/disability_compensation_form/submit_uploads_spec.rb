# frozen_string_literal: true

require 'rails_helper'
require 'sidekiq/testing'
Sidekiq::Testing.fake!

RSpec.describe EVSS::DisabilityCompensationForm::SubmitUploads, type: :job do
  before do
    unless defined?(Sidekiq::Batch)
      Sidekiq::Batch = Class.new do
        def on(callback, klass, options)
        end

        def jobs
          yield
        end
      end
    end
  end

  before(:each) do
    Sidekiq::Worker.clear_all
  end

  describe '.start' do
    let(:user) { FactoryBot.create(:user, :loa3) }

    context 'with four uploads' do
      let(:claim_id) { 123_456_789 }
      let(:uploads) do
        [
          { guid: SecureRandom.uuid },
          { guid: SecureRandom.uuid },
          { guid: SecureRandom.uuid },
          { guid: SecureRandom.uuid }
        ]
      end

      it 'queues four submit upload jobs' do
        allow(EVSS::DisabilityCompensationForm::SubmitUploads).to receive(:get_claim_id).and_return(claim_id)
        allow(EVSS::DisabilityCompensationForm::SubmitUploads).to receive(:get_uploads).and_return(uploads)
        expect {
          EVSS::DisabilityCompensationForm::SubmitUploads.start(user.uuid)
        }.to change(EVSS::DisabilityCompensationForm::SubmitUploads.jobs, :size).by(4)
      end
    end
  end
end
