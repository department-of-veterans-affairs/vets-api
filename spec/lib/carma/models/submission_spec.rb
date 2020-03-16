# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CARMA::Models::Submission, type: :model do
  describe '#new' do
    it 'accepts arguments' do
      expected = {
        carma_case_id: 'aB935000000A9GoCAK',
        submitted_at: DateTime.now.iso8601,
        data: { my: 'data' },
        claim_id: 3
      }

      submission = described_class.new(
        carma_case_id: expected[:carma_case_id],
        submitted_at: expected[:submitted_at],
        data: expected[:data],
        metadata: { claim_id: expected[:claim_id] }
      )

      expect(submission.carma_case_id).to eq(expected[:carma_case_id])
      expect(submission.submitted_at).to eq(expected[:submitted_at])
      expect(submission.data).to eq(expected[:data])
      expect(submission.metadata).to be_instance_of(described_class::Metadata)
      expect(submission.metadata.claim_id).to eq(expected[:claim_id])
    end
  end

  describe '#from_claim' do
    it 'transfroms a CaregiversAssistanceClaim to a new CARMA::Model::Submission' do
      claim = build(:caregivers_assistance_claim)

      submission = described_class.from_claim(claim)

      expect(submission).to be_instance_of(described_class)
      expect(submission.data).to eq(claim.parsed_form)
      expect(submission.carma_case_id).to eq(nil)
      expect(submission.submitted_at).to eq(nil)

      expect(submission.metadata).to be_instance_of(described_class::Metadata)
      expect(submission.metadata.claim_id).to eq(claim.id)
    end

    it 'will override :claim_id when passed in metadata and use claim.id instead' do
      claim = build(:caregivers_assistance_claim)

      submission = described_class.from_claim(claim, claim_id: 99)

      expect(submission).to be_instance_of(described_class)
      expect(submission.data).to eq(claim.parsed_form)
      expect(submission.carma_case_id).to eq(nil)
      expect(submission.submitted_at).to eq(nil)

      expect(submission.metadata).to be_instance_of(described_class::Metadata)
      expect(submission.metadata.claim_id).to eq(claim.id)
    end
  end

  describe '#submitted?' do
    it 'returns true if :carma_case_id is set' do
      submission = described_class.new(carma_case_id: 'aB935000000A9GoCAK')
      expect(submission.submitted?).to eq(true)
    end

    it 'returns true if :submitted_at is set' do
      submission = described_class.new(submitted_at: DateTime.now.iso8601)
      expect(submission.submitted?).to eq(true)
    end

    it 'returns false if :carma_case_id and :submitted_at are falsy' do
      submission = described_class.new
      expect(submission.submitted?).to eq(false)
    end
  end

  describe '#submit!' do
    let(:submission) do
      CARMA::Models::Submission.from_claim(
        build(:caregivers_assistance_claim)
      )
    end

    context 'when :data is invalid' do
      xit 'raises exception' do
      end
    end

    context 'when :metadata is invalid' do
      xit 'raises exception' do
      end
    end

    context 'when submission is valid' do
      it 'submits the data and metadata to CARMA, and updates :carma_case_id and :submitted_at' do
        expect(submission.carma_case_id).to eq(nil)
        expect(submission.submitted_at).to eq(nil)
        expect(submission.submitted?).to eq(false)

        expected_data = {
          'data' => {
            'carmacase' => {
              'id' => 'aB935000000F3VnCAK',
              'createdAt' => '2020-03-09T10:48:59Z'
            }
          }
        }

        expect_any_instance_of(CARMA::Client::Client).to receive(:create_submission_stub)
          .with(data: submission.data, metadata: { claim_id: nil })
          .and_return(expected_data)

        submission.submit!

        expect(submission.carma_case_id).to eq(expected_data['data']['carmacase']['id'])
        expect(submission.submitted_at).to eq(expected_data['data']['carmacase']['createdAt'])
        expect(submission.submitted?).to eq(true)
      end
    end

    context 'when already submitted' do
      it 'raises an exception' do
        submission.submitted_at = DateTime.now.iso8601
        submission.carma_case_id = 'aB935000000A9GoCAK'

        expect_any_instance_of(CARMA::Client::Client).not_to receive(:create_submission_stub)

        expect { submission.submit! }.to raise_error('This submission has already been submitted to CARMA')
      end
    end

    context 'when unauthorized' do
    end

    context 'when CARMA is down' do
    end
  end
end
