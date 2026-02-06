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

  let(:claim_without_download_eligible_documents) do
    subject.parse(claim_data[0])
  end

  let(:claim_with_tracked_documents) do
    subject.parse(claim_data[2])
  end

  let(:claim_with_untracked_documents) do
    subject.parse(claim_data[1])
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
                                     document_id: nil,
                                     # Content override fields should be nil when the feature flag is disabled
                                     activity_description: nil,
                                     can_upload_file: nil,
                                     friendly_name: nil,
                                     is_dbq: nil,
                                     is_proper_noun: nil,
                                     is_sensitive: nil,
                                     long_description: nil,
                                     next_steps: nil,
                                     no_action_needed: nil,
                                     no_provide_prefix: nil,
                                     short_description: nil,
                                     support_aliases: nil })
  end

  describe 'download_eligible_documents' do
    it 'does not have download_eligible_documents' do
      download_eligible_documents = claim_without_download_eligible_documents[:download_eligible_documents]
      expect(download_eligible_documents).to be_a(Array)
      expect(download_eligible_documents).to be_empty

      events_timeline = claim_without_download_eligible_documents[:events_timeline]
      expect(events_timeline).to include(an_object_having_attributes(
                                           document_id: '{798F828C-3B4A-4EB5-8883-F7C49205BD98}',
                                           filename: nil,
                                           documents: nil,
                                           type: :other_documents_list
                                         ))
    end

    it 'has download_eligible_documents with tracked documents' do
      download_eligible_documents = claim_with_tracked_documents[:download_eligible_documents]
      expect(download_eligible_documents).to be_a(Array)
      expect(download_eligible_documents.size).to eq(5)
      expect(download_eligible_documents[0][:document_id]).to eq('{883B6CC8-D726-4911-9C65-2EB360E12F52}')
      expect(download_eligible_documents[0][:filename]).to eq('7B434B58-477C-4379-816F-05E6D3A10487.pdf')

      events_timeline = claim_with_tracked_documents[:events_timeline]
      expect(events_timeline[3][:documents]).not_to be_empty
      expect(events_timeline[3][:document_id]).to be_nil
      expect(events_timeline[3][:type]).not_to eq(:other_documents_list)
    end

    it 'has download_eligible_documents with only untracked documents' do
      download_eligible_documents = claim_with_untracked_documents[:download_eligible_documents]
      expect(download_eligible_documents).to be_a(Array)
      expect(download_eligible_documents.size).to eq(5)
      expect(download_eligible_documents[0][:document_id]).to eq('{0C994A8F-F2FE-4963-B013-870E420EFFD1}')
      expect(download_eligible_documents[0][:filename]).to eq('ClaimDecisionRequest.pdf')
      events_timeline = claim_with_untracked_documents[:events_timeline]
      expect(events_timeline).to include(an_object_having_attributes(
                                           document_id: '{0C994A8F-F2FE-4963-B013-870E420EFFD1}',
                                           documents: nil,
                                           type: :other_documents_list
                                         ))
    end
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

  describe 'claim_type_base and display_title fields' do
    let(:test_claim) do
      subject.parse(claim_data[0])
    end

    context 'when title generator feature flag is enabled' do
      before do
        allow(Flipper).to(receive(:enabled?)
                            .with(Mobile::V0::Adapters::ClaimsOverview::FEATURE_USE_TITLE_GENERATOR_MOBILE)
                            .and_return(true))
      end

      it 'includes both claim_type_base and display_title in the response' do
        expect(test_claim[:claim_type_base]).not_to be_nil
        expect(test_claim[:display_title]).not_to be_nil
      end

      it 'populates claim_type_base with expected value' do
        expect(test_claim[:claim_type_base]).to be_a(String)
        expect(test_claim[:claim_type_base]).not_to be_empty
      end

      it 'populates display_title with expected value' do
        expect(test_claim[:display_title]).to be_a(String)
        expect(test_claim[:display_title]).not_to be_empty
      end
    end

    context 'when title generator feature flag is disabled' do
      before do
        allow(Flipper).to(receive(:enabled?)
                            .with(Mobile::V0::Adapters::ClaimsOverview::FEATURE_USE_TITLE_GENERATOR_MOBILE)
                            .and_return(false))
      end

      it 'includes claim_type_base in the response' do
        expect(test_claim[:claim_type_base]).not_to be_nil
      end

      it 'populates claim_type_base with expected value' do
        expect(test_claim[:claim_type_base]).to be_a(String)
        expect(test_claim[:claim_type_base]).not_to be_empty
      end

      it 'does not include display_title in the response' do
        expect(test_claim[:display_title]).to be_nil
      end
    end
  end

  describe 'tracked item content overrides' do
    let(:test_claim) do
      subject.parse(claim_data[2])
    end

    let(:real_content) do
      BenefitsClaims::TrackedItemContent.find_by_display_name('21-4142') # rubocop:disable Rails/DynamicFindBy
    end

    context "when the 'cst_evidence_requests_content_override_mobile' feature flag is enabled" do
      before do
        allow(Flipper).to receive(:enabled?)
          .with(Mobile::V0::Adapters::LighthouseIndividualClaims::FEATURE_EVIDENCE_REQUESTS_CONTENT_OVERRIDE)
          .and_return(true)
        allow(BenefitsClaims::TrackedItemContent).to receive(:find_by_display_name)
          .and_return(real_content)
      end

      it 'includes content override fields in tracked item events' do
        tracked_item = test_claim[:events_timeline].find do |event|
          %w[still_need_from_you_list received_from_you_list].include?(event[:type].to_s)
        end

        expect(tracked_item.friendly_name).to eq('Authorization to disclose information')
        expect(tracked_item.short_description).to eq(
          'We need your permission to request your personal information from a non-VA source, ' \
          'like a private doctor or hospital.'
        )
        expect(tracked_item.activity_description).to be_nil
        expect(tracked_item.support_aliases).to eq(['21-4142'])
        expect(tracked_item.can_upload_file).to be(true)
        expect(tracked_item.no_action_needed).to be(false)
        expect(tracked_item.is_dbq).to be(false)
        expect(tracked_item.is_proper_noun).to be(false)
        expect(tracked_item.is_sensitive).to be(false)
        expect(tracked_item.no_provide_prefix).to be(false)
        expect(tracked_item.long_description).to be_a(Hash)
        expect(tracked_item.next_steps).to be_a(Hash)
      end
    end

    context "when the 'cst_evidence_requests_content_override_mobile' feature flag is disabled" do
      before do
        allow(Flipper).to receive(:enabled?)
          .with(Mobile::V0::Adapters::LighthouseIndividualClaims::FEATURE_EVIDENCE_REQUESTS_CONTENT_OVERRIDE)
          .and_return(false)
      end

      it 'does not include content override fields in tracked item events' do
        tracked_item = test_claim[:events_timeline].find do |event|
          %w[still_need_from_you_list received_from_you_list].include?(event[:type].to_s)
        end

        expect(tracked_item.friendly_name).to be_nil
        expect(tracked_item.short_description).to be_nil
        expect(tracked_item.activity_description).to be_nil
        expect(tracked_item.support_aliases).to be_nil
        expect(tracked_item.can_upload_file).to be_nil
        expect(tracked_item.no_action_needed).to be_nil
        expect(tracked_item.is_dbq).to be_nil
        expect(tracked_item.is_proper_noun).to be_nil
        expect(tracked_item.is_sensitive).to be_nil
        expect(tracked_item.no_provide_prefix).to be_nil
        expect(tracked_item.long_description).to be_nil
        expect(tracked_item.next_steps).to be_nil
      end

      it 'does not call TrackedItemContent lookup' do
        expect(BenefitsClaims::TrackedItemContent).not_to receive(:find_by_display_name)
        test_claim
      end
    end
  end
end
