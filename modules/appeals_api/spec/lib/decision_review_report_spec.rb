# frozen_string_literal: true

require 'rails_helper'
require 'appeals_api/decision_review_report'

describe AppealsApi::DecisionReviewReport do
  # rubocop:disable Layout/FirstHashElementIndentation
  it 'can correctly calculate hlrs' do
    create :higher_level_review, status: 'processing'
    create :higher_level_review, status: 'processing'
    create :higher_level_review, status: 'processing'

    create :higher_level_review, created_at: 1.week.ago, status: 'success'
    create :higher_level_review, status: 'success'
    create :higher_level_review, status: 'success'

    create :higher_level_review, :status_error

    subject = described_class.new(from: 5.days.ago, to: Time.now.utc)

    expect(subject.hlr_by_status_and_count).to eq({
      'caseflow' => 0,
      'error' => 1,
      'expired' => 0,
      'pending' => 0,
      'processing' => 3,
      'received' => 0,
      'submitted' => 0,
      'submitting' => 0,
      'success' => 2,
      'uploaded' => 0
    })
  end

  describe '#faulty_hlr' do
    let(:old_error) { create(:higher_level_review, :status_error, created_at: 1.year.ago) }
    let(:recent_error) { create(:higher_level_review, :status_error, created_at: 1.day.ago) }

    it 'will retrieve recent errored records if dates are provided' do
      subject = described_class.new(from: 5.days.ago, to: Time.now.utc)

      expect(subject.faulty_hlr).to eq([recent_error])
    end

    it 'will retrieve all errored records if no dates are provided' do
      subject = described_class.new(from: nil, to: nil)

      expect(subject.faulty_hlr).to eq([recent_error, old_error])
    end
  end

  it 'can correctly calculate nods' do
    create :notice_of_disagreement, created_at: 1.week.ago, status: 'success'
    create :notice_of_disagreement, status: 'success'
    create :notice_of_disagreement, status: 'success'

    create :notice_of_disagreement, :status_error

    subject = described_class.new(from: 5.days.ago, to: Time.now.utc)

    expect(subject.nod_by_status_and_count).to eq({
      'error' => 1,
      'pending' => 0,
      'processing' => 0,
      'submitted' => 0,
      'submitting' => 0,
      'success' => 2,
      'caseflow' => 0
    })
  end
  # rubocop:enable Layout/FirstHashElementIndentation

  describe '#faulty_nod' do
    let(:old_error) { create(:notice_of_disagreement, :status_error, created_at: 1.year.ago) }
    let(:recent_error) { create(:notice_of_disagreement, :status_error, created_at: 1.day.ago) }

    it 'will retrieve recent errored records if dates are provided' do
      subject = described_class.new(from: 5.days.ago, to: Time.now.utc)

      expect(subject.faulty_nod).to eq([recent_error])
    end

    it 'will retrieve all errored records if no dates are provided' do
      subject = described_class.new(from: nil, to: nil)

      expect(subject.faulty_nod).to eq([recent_error, old_error])
    end
  end

  describe '#no_faulty_records?' do
    it 'returns false if there are records with a faulty status' do
      create :notice_of_disagreement, :status_error

      expect(described_class.new.no_faulty_records?).to eq(false)
    end

    it 'returns true if there are no records with a faulty status' do
      expect(described_class.new.no_faulty_records?).to eq(true)
    end
  end
end
