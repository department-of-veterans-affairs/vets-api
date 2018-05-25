# frozen_string_literal: true

require 'rails_helper'
require 'sidekiq/testing'
Sidekiq::Testing.fake!

RSpec.describe EVSS::DisabilityCompensationForm::SubmitUploads, type: :job do
  before(:each) do
    Sidekiq::Worker.clear_all
  end

  describe '.start' do
    let(:user) { FactoryBot.create(:user, :loa3) }
    let(:auth_headers) { EVSS::AuthHeaders.new(user).to_h }
    let(:claim_id) { 123_456_789 }

    subject { described_class }

    context 'with four uploads' do
      let(:uploads) do
        [
          { guid: SecureRandom.uuid },
          { guid: SecureRandom.uuid },
          { guid: SecureRandom.uuid },
          { guid: SecureRandom.uuid }
        ]
      end

      it 'queues four submit upload jobs' do
        allow(subject).to receive(:get_claim_id).and_return(claim_id)
        allow(subject).to receive(:get_uploads).and_return(uploads)
        expect do
          subject.start(user.uuid, auth_headers)
        end.to change(subject.jobs, :size).by(4)
      end
    end

    context 'with no uploads' do
      let(:uploads) { [] }

      it 'queues no submit upload jobs' do
        allow(subject).to receive(:get_claim_id).and_return(claim_id)
        allow(subject).to receive(:get_uploads).and_return(uploads)
        expect do
          subject.start(user.uuid, auth_headers)
        end.to_not change(subject.jobs, :size)
      end
    end
  end
end
