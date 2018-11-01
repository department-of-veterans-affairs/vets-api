# frozen_string_literal: true

require 'rails_helper'
require 'sidekiq/testing'
Sidekiq::Testing.fake!

RSpec.describe EVSS::DisabilityCompensationForm::AncillaryJobs do
  let(:bid) { SecureRandom.hex(8) }
  let(:user) { FactoryBot.create(:user, :loa3) }
  let(:auth_headers) do
    EVSS::DisabilityCompensationAuthHeaders.new(user).add_headers(EVSS::AuthHeaders.new(user).to_h)
  end
  let(:saved_claim_id) { 1_234_567 }
  let(:claim_id) { 1_234_567 }
  let(:submission_data) do
    {
      'form526' => '{"form526": "json"}',
      'form526_uploads' => uploads,
      'form4142' => form4142,
      'form0781' => form0781
    }
  end
  let(:uploads) { [] }
  let(:form4142) { nil }
  let(:form0781) { nil }

  subject { described_class.new(user.uuid, auth_headers, saved_claim_id, submission_data) }

  before(:each) do
    Sidekiq::Worker.clear_all
  end

  describe 'perform' do
    context 'when there are uploads' do
      let(:uploads) do
        [
          {
            'name' => 'private_medical_record.pdf',
            'confirmationCode' => 'd44d6f52-2e85-43d4-a5a3-1d9cb4e482a0',
            'attachmentId' => 'L451'
          },
          {
            'name' => 'private_medical_record_2.pdf',
            'confirmationCode' => 'd44d6f52-2e85-43d4-a5a3-1d9cb4e482a1',
            'attachmentId' => 'L451'
          }
        ]
      end

      it 'queues two jobs' do
        expect do
          subject.perform(bid, claim_id)
        end.to change(EVSS::DisabilityCompensationForm::SubmitUploads.jobs, :size).by(2)
      end
    end

    context 'when there are no uploads' do
      it 'queues no jobs' do
        expect do
          subject.perform(bid, claim_id)
        end.to change(EVSS::DisabilityCompensationForm::SubmitUploads.jobs, :size).by(0)
      end
    end

    context 'when there is no 4142 form' do
      it 'does not queue a job' do
        expect do
          subject.perform(bid, claim_id)
        end.to change(CentralMail::SubmitForm4142Job.jobs, :size).by(0)
      end
    end

    context 'when there is a 4142 form' do
      let(:form4142) { '{"form4142": "json"}' }

      it 'queues one job' do
        expect do
          subject.perform(bid, claim_id)
        end.to change(CentralMail::SubmitForm4142Job.jobs, :size).by(1)
      end
    end

    context 'when there is no 0781 form' do
      it 'does not queue a job' do
        expect do
          subject.perform(bid, claim_id)
        end.to change(EVSS::DisabilityCompensationForm::SubmitForm0781.jobs, :size).by(0)
      end
    end

    context 'when there is a 0781 form' do
      let(:form0781) { '{"form0781": "json"}' }

      it 'queues one job' do
        expect do
          subject.perform(bid, claim_id)
        end.to change(EVSS::DisabilityCompensationForm::SubmitForm0781.jobs, :size).by(1)
      end
    end
  end
end
