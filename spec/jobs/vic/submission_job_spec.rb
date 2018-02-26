# frozen_string_literal: true

require 'rails_helper'

RSpec.describe VIC::SubmissionJob do
  let(:uuid) { 'fab2eea7-982e-4171-a2cb-8e9455ab00ed' }
  let(:user) { create(:user, :loa3) }

  describe '#perform' do
    context 'when the service is up' do
      let(:vic_submission) { build(:vic_submission) }

      before do
        vic_submission.user_uuid = user.uuid
        vic_submission.save!
      end

      context 'when files arent processed yet', run_at: '2017-01-04 07:00:00 UTC' do
        it 'should reenqueue the job' do
          expect(described_class).to receive(:perform_async).with(
            vic_submission.id,
            vic_submission.form,
            user.uuid,
            '2017-01-04 07:00:00 UTC'
          )
          expect_any_instance_of(VIC::Service).to receive(:sleep).with(1)
          described_class.drain

          expect(vic_submission.reload.state).to eq('pending')
        end

        context 'when its been over the time limit' do
          it 'should raise timeout error' do
            expect do
              described_class.new.perform(vic_submission.id, vic_submission.form, user.uuid, '2016-01-04 07:00:00 UTC')
            end.to raise_error(Timeout::Error)

            expect(vic_submission.reload.state).to eq('failed')
          end
        end
      end

      context 'with a valid vic submission' do
        before do
          expect(User).to receive(:find).with(user.uuid).and_return(user)
          expect_any_instance_of(VIC::Service).to receive(:submit).with(
            JSON.parse(vic_submission.form), user
          ).and_return(case_id: uuid)
          vic_submission.save!
          ProcessFileJob.drain
        end

        it 'should update the vic submission response' do
          described_class.drain
          vic_submission.reload

          expect(vic_submission.state).to eq('success')
          expect(vic_submission.response).to eq(
            'case_id' => uuid
          )
        end

        it 'should delete uploads after submission' do
          expect do
            described_class.drain
          end.to change(::VIC::SupportingDocumentationAttachment, :count)
            .by(-1)
            .and change(::VIC::ProfilePhotoAttachment, :count)
            .by(-1)
        end
      end
    end

    context 'when the service has an error' do
      it 'should set the submission to failed' do
        vic_submission = create(:vic_submission)
        ProcessFileJob.drain
        expect_any_instance_of(VIC::Service).to receive(:submit).and_raise('foo')
        expect do
          described_class.drain
        end.to raise_error('foo')
        vic_submission.reload

        expect(vic_submission.state).to eq('failed')
      end
    end
  end
end
