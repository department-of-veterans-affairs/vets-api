# frozen_string_literal: true

require 'rails_helper'
require 'forms/submission_statuses/dataset'
require 'forms/submission_statuses/formatters/decision_reviews_formatter'

describe Forms::SubmissionStatuses::Formatters::DecisionReviewsFormatter,
         feature: :form_submission,
         team_owner: :vfs_authenticated_experience_backend do
  subject { described_class.new }

  describe '#format_data' do
    let(:user_account) { create(:user_account) }
    let(:saved_claim) { create(:saved_claim_supplemental_claim) }
    let(:dataset) { instance_double(Forms::SubmissionStatuses::Dataset) }

    context 'with submissions but no statuses' do
      before do
        allow(dataset).to receive_messages(
          submissions?: true,
          submissions: [saved_claim],
          intake_statuses?: false,
          intake_statuses: nil
        )
      end

      it 'formats submissions with correct attributes' do
        result = subject.format_data(dataset)

        expect(result.size).to eq(1)
        record = result.first

        expect(record.id).to eq(saved_claim.guid)
        expect(record.form_type).to eq('20-0995')
        expect(record.created_at).to eq(saved_claim.created_at)
        expect(record.status).to be_nil # No status data provided
      end
    end
  end

  describe '#format_data with statuses' do
    let(:saved_claim) { create(:saved_claim_supplemental_claim) }
    let(:dataset) { instance_double(Forms::SubmissionStatuses::Dataset) }
    let(:statuses_data) do
      [
        {
          'attributes' => {
            'guid' => saved_claim.guid,
            'status' => 'complete',
            'detail' => 'Claim processed',
            'updated_at' => '2024-01-01T10:00:00.000Z'
          }
        }
      ]
    end

    before do
      allow(dataset).to receive_messages(
        submissions?: true,
        submissions: [saved_claim],
        intake_statuses?: true,
        intake_statuses: statuses_data
      )
    end

    it 'merges submissions with statuses correctly' do
      result = subject.format_data(dataset)

      expect(result.size).to eq(1)
      record = result.first

      expect(record.id).to eq(saved_claim.guid)
      expect(record.status).to eq('complete')
      expect(record.detail).to eq('Claim processed')
      expect(record.updated_at).to be_a(Time)
    end

    context 'with missing updateDate' do
      let(:statuses_data) do
        [
          {
            'attributes' => {
              'guid' => saved_claim.guid,
              'status' => 'processing'
            }
          }
        ]
      end

      it 'handles missing date gracefully' do
        result = subject.format_data(dataset)

        expect(result.size).to eq(1)
        record = result.first
        expect(record.updated_at).to be_nil
      end
    end
  end

  describe 'secondary form support' do
    let(:saved_claim) { create(:saved_claim_supplemental_claim) }
    let(:dataset) { instance_double(Forms::SubmissionStatuses::Dataset) }
    let(:secondary_form_status) do
      {
        'attributes' => {
          'guid' => 'secondary-guid-123',
          'status' => 'vbms',
          'detail' => 'Secondary form processed',
          'form_type' => 'form0995_form4142'
        }
      }
    end

    before do
      allow(dataset).to receive_messages(
        submissions?: true,
        submissions: [saved_claim],
        intake_statuses?: true,
        intake_statuses: [secondary_form_status]
      )
    end

    it 'creates entries for secondary forms' do
      result = subject.format_data(dataset)

      expect(result.size).to eq(2) # One for saved_claim, one for secondary form

      secondary_record = result.find { |r| r.id == 'secondary-guid-123' }
      expect(secondary_record).not_to be_nil
      expect(secondary_record.form_type).to eq('form0995_form4142')
      expect(secondary_record.status).to eq('vbms')
    end
  end

  describe 'private methods' do
    describe '#determine_form_type' do
      it 'maps SupplementalClaim to 20-0995' do
        saved_claim = create(:saved_claim_supplemental_claim)
        form_type = subject.send(:determine_form_type, saved_claim)
        expect(form_type).to eq('20-0995')
      end

      it 'maps HigherLevelReview to 20-0996' do
        saved_claim = create(:saved_claim_higher_level_review)
        form_type = subject.send(:determine_form_type, saved_claim)
        expect(form_type).to eq('20-0996')
      end

      it 'maps NoticeOfDisagreement to 10182' do
        saved_claim = create(:saved_claim_notice_of_disagreement)
        form_type = subject.send(:determine_form_type, saved_claim)
        expect(form_type).to eq('10182')
      end

      it 'maps SecondaryAppealForm to its form_id' do
        secondary_form = create(:secondary_appeal_form4142, form_id: '21-4142')
        form_type = subject.send(:determine_form_type, secondary_form)
        expect(form_type).to eq('form0995_form4142')
      end

      it 'returns unknown for unknown claim types' do
        saved_claim = double(class: double(name: 'SavedClaim::UnknownClaim'))
        form_type = subject.send(:determine_form_type, saved_claim)
        expect(form_type).to eq('unknown')
      end
    end

    describe '#parse_date' do
      it 'parses valid ISO date string' do
        date_string = '2024-01-01T10:00:00.000Z'
        result = subject.send(:parse_date, date_string)
        expect(result).to eq(Time.zone.parse(date_string))
      end

      it 'returns nil for invalid date' do
        result = subject.send(:parse_date, 'invalid-date')
        expect(result).to be_nil
      end

      it 'returns nil for nil input' do
        result = subject.send(:parse_date, nil)
        expect(result).to be_nil
      end
    end
  end
end
