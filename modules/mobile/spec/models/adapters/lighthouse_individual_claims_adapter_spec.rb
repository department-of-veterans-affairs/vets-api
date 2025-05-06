# frozen_string_literal: true

require 'rails_helper'

describe Mobile::V0::Adapters::LighthouseIndividualClaims, :aggregate_failures do
  def claim_data
    JSON.parse(claims_fixture, symbolize_names: false)
  end

  let(:claims_fixture) do
    Rails.root.join('modules', 'mobile', 'spec', 'support', 'fixtures', 'individual_claims.json').read
  end

  let(:under_review_claim) do
    subject.parse(claim_data[1])
  end

  let(:gathering_of_evidence_claim) do
    subject.parse(claim_data[2])
  end

  it 'returns nil when provided nil' do
    expect(subject.parse(nil)).to be_nil
  end

  it 'returns expected other documents in events_timeline field' do
    other_documents_list = under_review_claim[:events_timeline].select { |event| event[:type] == :other_documents_list }
    expect(other_documents_list.size).to eq(13)
    expect(other_documents_list.map(&:document_id)).to include('{7AF4C5E0-EBCE-49B2-9544-999ECA2904FD}')
  end

  it 'returns expected filed event in events_timeline field' do
    filed = under_review_claim[:events_timeline].select { |event| event[:type] == :filed }
    expect(filed.size).to eq(1)
    expect(filed.first[:date].to_s).to eq('2021-03-22')
  end

  it 'returns expected phase events in events_timeline field' do
    phases = under_review_claim[:events_timeline].select { |event| event[:type].to_s.include?('phase') }
    expect(phases.size).to eq(1)
    expect(phases.first[:type]).to eq('phase1')
    expect(phases.first[:date].to_s).to eq('2021-03-22')
  end

  it 'returns expected tracked items events in events_timeline field' do
    tracked_items = gathering_of_evidence_claim[:events_timeline].filter_map do |event|
      event.to_h if %w[still_need_from_you_list received_from_you_list].include?(event[:type].to_s)
    end

    expect(tracked_items.size).to eq(8)
    expect(tracked_items[3]).to eq({ type: 'received_from_you_list',
                                     tracked_item_id: 360_052,
                                     description: 'The information provided concerning your prior marital history' \
                                                  ' is inconsistent.  In order to resolve these inconsistencies ' \
                                                  'you should submit certified copies of the public record of the' \
                                                  ' termination (death, divorce or annulment) for each of your' \
                                                  ' prior marriages.',
                                     display_name: 'Claimant marital history inconsistent - need proof',
                                     overdue: true,
                                     status: 'NEEDED',
                                     uploaded: true,
                                     uploads_allowed: true,
                                     opened_date: '2022-09-30',
                                     requested_date: '2022-09-30',
                                     received_date: nil,
                                     closed_date: nil,
                                     suspense_date: '2022-10-30',
                                     documents: [{ tracked_item_id: 360_052,
                                                   file_type: 'Civilian Police Reports',
                                                   document_type: nil,
                                                   filename: '7B434B58-477C-4379-816F-05E6D3A10487.pdf',
                                                   upload_date: '2023-03-01',
                                                   document_id: '{883B6CC8-D726-4911-9C65-2EB360E12F52}' }],
                                     upload_date: '2023-03-01',
                                     date: Date.new(2023, 3, 1),
                                     file_type: nil,
                                     document_type: nil,
                                     filename: nil,
                                     document_id: nil })
  end

  context 'with claim in phase CLAIM_RECEIVED' do
    let(:claim_received_claim) do
      subject.parse(claim_data[0])
    end

    it 'returns expected fields' do
      expect(claim_received_claim[:phase]).to eq(1)
      expect(claim_received_claim[:open]).to be(true)
    end
  end

  context 'with claim in phase UNDER_REVIEW' do
    it 'returns expected fields' do
      expect(under_review_claim[:phase]).to eq(2)
      expect(under_review_claim[:open]).to be(true)
      expect(under_review_claim[:contention_list]).to eq(['Post Traumatic Stress Disorder (PTSD) ' \
                                                          'Combat - Mental Disorders (New)'])
    end
  end

  context 'with claim in phase GATHERING_OF_EVIDENCE' do
    it 'returns expected fields' do
      expect(gathering_of_evidence_claim[:phase]).to eq(3)
      expect(gathering_of_evidence_claim[:open]).to be(true)
    end
  end

  context 'with claim in phase REVIEW_OF_EVIDENCE' do
    let(:review_of_evidence_claim) do
      subject.parse(claim_data[3])
    end

    it 'returns expected fields' do
      expect(review_of_evidence_claim[:phase]).to eq(4)
      expect(review_of_evidence_claim[:open]).to be(true)
    end
  end

  context 'with claim in phase PREPARATION_FOR_DECISION' do
    let(:preparation_for_decision_claim) do
      subject.parse(claim_data[4])
    end

    it 'returns expected fields' do
      expect(preparation_for_decision_claim[:phase]).to eq(5)
      expect(preparation_for_decision_claim[:open]).to be(true)
    end
  end

  context 'with claim in phase COMPLETE' do
    let(:complete_claim) do
      subject.parse(claim_data[5])
    end

    it 'returns expected fields' do
      expect(complete_claim[:phase]).to eq(8)
      expect(complete_claim[:open]).to be(false)
      expect(complete_claim[:contention_list]).to eq(['Abdominal pain, etiology unknown (New)',
                                                      'Post Traumatic Stress Disorder (PTSD) ' \
                                                      'Combat - Mental Disorders (New)'])
    end
  end
end
