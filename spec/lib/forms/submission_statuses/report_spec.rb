# frozen_string_literal: true

require 'rails_helper'
require 'forms/submission_statuses/gateways/benefits_intake_gateway'
require 'forms/submission_statuses/report'

describe Forms::SubmissionStatuses::Report, feature: :form_submission,
                                            team_owner: :vfs_authenticated_experience_backend do
  subject { described_class.new(user_account:, allowed_forms:) }

  let(:user_account) { create(:user_account) }
  let(:allowed_forms) { %w[20-10207 21-0845 21-0972 21-10210 21-4142 21-4142a 21P-0847 21-4140 21P-530EZ] }
  let(:benefits_intake_service) { instance_double(BenefitsIntake::Service) }
  let(:benefits_intake_gateway) { Forms::SubmissionStatuses::Gateways::BenefitsIntakeGateway }

  context 'when user has no submissions' do
    before do
      allow_any_instance_of(benefits_intake_gateway).to receive(:submissions).and_return([])
      allow_any_instance_of(benefits_intake_gateway).to receive(:lighthouse_submissions).and_return([])
      allow_any_instance_of(benefits_intake_gateway).to receive(:intake_statuses).and_return([nil, nil])
    end

    it 'returns an empty array' do
      result = subject.run
      expect(result.submission_statuses).to eq([])
    end
  end

  context 'when user has form submissions only' do
    before do
      create(:form_submission, :with_form214142, user_account_id: user_account.id)
      create(:form_submission, :with_form210845, user_account_id: user_account.id)
      create(:form_submission, :with_form214140, user_account_id: user_account.id)

      # This form is not in the allowed forms list and should not be included
      create(:form_submission, :with_form_blocked, user_account_id: user_account.id)

      # This 20-10207 form is older than 60 days and should not be included in the results
      create(:form_submission, :with_form2010207, user_account_id: user_account.id)

      allow_any_instance_of(benefits_intake_gateway).to receive(:lighthouse_submissions).and_return([])
    end

    context 'has statuses' do
      before do
        # Mock successful bulk_status response
        allow(BenefitsIntake::Service).to receive(:new).and_return(benefits_intake_service)
        allow(benefits_intake_service).to receive(:bulk_status).and_return(
          double(body: {
                   'data' => [
                     {
                       'id' => '4b846069-e496-4f83-8587-42b570f24483',
                       'attributes' => {
                         'detail' => 'detail',
                         'guid' => '4b846069-e496-4f83-8587-42b570f24483',
                         'message' => 'message',
                         'status' => 'received',
                         'updated_at' => 2.days.ago
                       }
                     },
                     {
                       'id' => 'd0c6cea6-9885-4e2f-8e0c-708d5933833a',
                       'attributes' => {
                         'detail' => 'detail',
                         'guid' => 'd0c6cea6-9885-4e2f-8e0c-708d5933833a',
                         'message' => 'message',
                         'status' => 'received',
                         'updated_at' => 3.days.ago
                       }
                     },
                     {
                       'id' => 'a1b2c3d4-e496-4f83-8587-42b570f24483',
                       'attributes' => {
                         'detail' => 'detail',
                         'guid' => 'a1b2c3d4-e496-4f83-8587-42b570f24483',
                         'message' => 'message',
                         'status' => 'received',
                         'updated_at' => 1.day.ago
                       }
                     }
                   ]
                 })
        )
      end

      it 'returns the correct count' do
        result = subject.run

        expect(result.submission_statuses.size).to be(3)
        expect(result.errors).to be_empty
      end

      it 'sorts results' do
        result = subject.run

        submission_statuses = result.submission_statuses
        expect(submission_statuses.first.updated_at).to be <= submission_statuses.last.updated_at
      end

      it 'returns the correct values' do
        result = subject.run

        submission_status = result.submission_statuses.first
        expect(submission_status.id).to eq('d0c6cea6-9885-4e2f-8e0c-708d5933833a')
        expect(submission_status.detail).to eq('detail')
        expect(submission_status.form_type).to eq('21-0845')
        expect(submission_status.message).to eq('message')
        expect(submission_status.status).to eq('received')
        expect(submission_status.pdf_support).to be(true)
      end
    end
  end

  context 'when user has lighthouse submissions only' do
    let!(:saved_claim) { create(:burials_saved_claim, :pending, user_account:) }
    let!(:lighthouse_submission) { saved_claim.lighthouse_submissions.first }

    before do
      allow_any_instance_of(benefits_intake_gateway).to receive(:form_submissions).and_return([])
    end

    context 'has statuses' do
      before do
        benefits_intake_uuid = lighthouse_submission.submission_attempts.last&.benefits_intake_uuid || 'test-uuid-123'
        lighthouse_intake_statuses = [
          [
            {
              'id' => benefits_intake_uuid,
              'attributes' => {
                'detail' => 'lighthouse detail',
                'guid' => benefits_intake_uuid,
                'message' => 'lighthouse message',
                'status' => 'pending',
                'updated_at' => 1.day.ago
              }
            }
          ],
          nil
        ]

        allow_any_instance_of(benefits_intake_gateway).to receive(
          :intake_statuses
        ).and_return(lighthouse_intake_statuses)
      end

      it 'returns lighthouse submission data' do
        result = subject.run

        expect(result.submission_statuses.size).to be(1)
        submission_status = result.submission_statuses.first

        benefits_intake_uuid = lighthouse_submission.submission_attempts.last&.benefits_intake_uuid || 'test-uuid-123'
        expect(submission_status.id).to eq(benefits_intake_uuid)
        expect(submission_status.form_type).to eq('21P-530EZ')
        expect(submission_status.status).to eq('pending')
      end
    end
  end

  context 'when user has mixed submissions' do
    let!(:saved_claim) { create(:burials_saved_claim, :pending, user_account:) }
    let!(:lighthouse_submission) { saved_claim.lighthouse_submissions.first }

    before do
      create(:form_submission, :with_form214142, user_account_id: user_account.id)
    end

    context 'combines both submission types' do
      before do
        benefits_intake_uuid = lighthouse_submission.submission_attempts.last&.benefits_intake_uuid || 'test-uuid-123'
        mixed_intake_statuses = [
          [
            {
              'id' => '4b846069-e496-4f83-8587-42b570f24483',
              'attributes' => {
                'status' => 'received',
                'updated_at' => 2.days.ago,
                'detail' => 'form submission detail',
                'guid' => '4b846069-e496-4f83-8587-42b570f24483',
                'message' => 'form submission message'
              }
            },
            {
              'id' => benefits_intake_uuid,
              'attributes' => {
                'status' => 'processing',
                'updated_at' => 1.day.ago,
                'detail' => 'lighthouse detail',
                'guid' => benefits_intake_uuid,
                'message' => 'lighthouse message'
              }
            }
          ],
          nil
        ]

        allow_any_instance_of(benefits_intake_gateway).to receive(
          :intake_statuses
        ).and_return(mixed_intake_statuses)
      end

      it 'returns combined submission count' do
        result = subject.run

        expect(result.submission_statuses.size).to be(2)

        # Check we have both types
        form_types = result.submission_statuses.map(&:form_type)
        expect(form_types).to include('21-4142', '21P-530EZ')
      end

      it 'sorts by creation time across both types' do
        result = subject.run

        submission_statuses = result.submission_statuses
        expect(submission_statuses.first.updated_at).to be <= submission_statuses.last.updated_at

        # Verify the sorting order - older should come first
        expect(submission_statuses.first.updated_at.to_date).to eq(2.days.ago.to_date)
        expect(submission_statuses.last.updated_at.to_date).to eq(1.day.ago.to_date)
      end
    end
  end

  context 'when no statuses' do
    before do
      create(:form_submission, :with_form214142, user_account_id: user_account.id)

      allow_any_instance_of(benefits_intake_gateway).to receive(:lighthouse_submissions).and_return([])
      allow_any_instance_of(benefits_intake_gateway).to receive(:intake_statuses).and_return([nil, nil])
    end

    it 'returns the correct count' do
      result = subject.run

      expect(result.submission_statuses.size).to be(1)
    end

    it 'returns the correct values' do
      result = subject.run

      submission_status = result.submission_statuses.first
      expect(submission_status.id).to eq('4b846069-e496-4f83-8587-42b570f24483')
      expect(submission_status.detail).to be_nil
      expect(submission_status.form_type).to eq('21-4142')
      expect(submission_status.message).to be_nil
      expect(submission_status.status).to be_nil
      expect(submission_status.pdf_support).to be(true)
    end
  end

  context 'logging errors' do
    let(:logger) { Rails.logger }

    context 'when gateway returns errors' do
      before do
        # Create submissions so the gateway has data to process
        create(:form_submission, :with_form214142, user_account_id: user_account.id)

        # Mock service error response
        error_response = double(status: 500, body: { 'errors' => [{ 'detail' => 'Service unavailable' }] })
        allow(BenefitsIntake::Service).to receive(:new).and_return(benefits_intake_service)
        allow(benefits_intake_service).to receive(:bulk_status).and_raise(
          Common::Exceptions::BackendServiceException.new('BENEFITS_INTAKE_ERROR', {},
                                                          error_response.status,
                                                          error_response.body)
        )
      end

      it 'logs gateway errors' do
        expect(logger).to receive(:error).with(
          'Gateway errors encountered when retrieving data in Forms::SubmissionStatuses::Report',
          hash_including(
            service: 'lighthouse_benefits_intake',
            errors: instance_of(Array)
          )
        )

        subject.run
      end
    end

    context 'when formatter is missing' do
      before do
        stub_const('Forms::SubmissionStatuses::Report::FORMATTERS', {})
      end

      it 'logs missing formatter error' do
        expect(logger).to receive(:error).with(
          'Report execution failed in Forms::SubmissionStatuses::Report',
          hash_including(
            error: 'Missing formatter for service: lighthouse_benefits_intake',
            service: 'lighthouse_benefits_intake',
            error_source: 'data_formatting'
          )
        )

        expect { subject.run }.to raise_error(RuntimeError)
      end
    end

    context 'when an unexpected error occurs' do
      context 'when retrieving data' do
        before do
          # Create submissions so the gateway has data to process
          create(:form_submission, :with_form214142, user_account_id: user_account.id)

          # Mock an error that will cause the gateway to fail at the gateway level
          # This simulates a scenario where the gateway itself fails, not just the service call
          allow_any_instance_of(benefits_intake_gateway).to receive(:data).and_raise(StandardError, 'Unexpected error')
        end

        it 'logs unexpected errors' do
          expect(logger).to receive(:error).with(
            'Report execution failed in Forms::SubmissionStatuses::Report',
            hash_including(
              error: 'Unexpected error',
              service: 'lighthouse_benefits_intake',
              error_source: 'data_retrieval_from_gateway'
            )
          )

          expect { subject.run }.to raise_error(StandardError)
        end
      end

      context 'when formatting data' do
        let(:formatter) { instance_double(Forms::SubmissionStatuses::Formatters::BenefitsIntakeFormatter) }

        before do
          allow_any_instance_of(benefits_intake_gateway).to receive(
            :data
          ).and_return(OpenStruct.new(submissions?: true, errors: []))

          stub_const(
            'Forms::SubmissionStatuses::Report::FORMATTERS',
            { 'lighthouse_benefits_intake' => formatter }
          )

          allow(formatter)
            .to receive(:format_data)
            .and_raise(StandardError, 'Formatter error')
        end

        it 'logs formatter errors' do
          expect(logger).to receive(:error).with(
            'Report execution failed in Forms::SubmissionStatuses::Report',
            hash_including(
              error: 'Formatter error',
              service: 'lighthouse_benefits_intake',
              error_source: 'data_formatting'
            )
          )

          expect { subject.run }.to raise_error(StandardError)
        end
      end
    end
  end
end
