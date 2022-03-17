# frozen_string_literal: true

require 'rails_helper'
require 'sidekiq/testing'

RSpec.describe RapidReadyForDecision::Form526AsthmaJob, type: :worker do
  subject { described_class }

  before do
    Sidekiq::Worker.clear_all
  end

  let(:submission) { create(:form526_submission, :with_uploads) }

  describe '#perform' do
    subject { RapidReadyForDecision::Form526AsthmaJob.perform_async(submission.id) }

    context 'success' do
      before do
        allow_any_instance_of(Lighthouse::VeteransHealth::Client).to receive('list_resource').and_return([])
      end

      it 'finishes successfully' do
        Sidekiq::Testing.inline! do
          expect { subject }.not_to raise_error
          expect(ActionMailer::Base.deliveries.last.subject).to eq 'RRD claim - Offramped'
        end
      end

      it 'creates a job status record' do
        Sidekiq::Testing.inline! do
          expect { subject }.to change(Form526JobStatus, :count).by(1)
        end
      end

      it 'marks the new Form526JobStatus record as successful' do
        Sidekiq::Testing.inline! do
          subject
          expect(Form526JobStatus.last.status).to eq 'success'
        end
      end
    end
  end
end
