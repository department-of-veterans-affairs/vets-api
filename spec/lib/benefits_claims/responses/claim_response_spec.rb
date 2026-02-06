# frozen_string_literal: true

require 'rails_helper'
require 'benefits_claims/responses/claim_response'

RSpec.describe BenefitsClaims::Responses::ClaimResponse do
  let(:claim_phase_dates) do
    BenefitsClaims::Responses::ClaimPhaseDates.new(
      phase_change_date: '2017-10-18',
      current_phase_back: false,
      phase_type: 'COMPLETE',
      latest_phase_type: 'COMPLETE',
      previous_phases: {}
    )
  end

  let(:tracked_items) do
    [
      BenefitsClaims::Responses::TrackedItem.new(
        id: 1,
        display_name: 'PMR Pending',
        status: 'NEEDED_FROM_YOU',
        suspense_date: '2026-12-01',
        type: 'other',
        closed_date: nil,
        description: 'Please submit your private medical records',
        overdue: false,
        received_date: nil,
        requested_date: '2024-11-01',
        uploads_allowed: true,
        uploaded: false,
        friendly_name: 'Private Medical Records',
        friendly_description: 'We need your medical records from private providers',
        can_upload_file: true,
        support_aliases: ['PMR', 'Medical Records'],
        documents: '[]',
        date: '2024-11-01',
        # New content override fields (populated when cst_evidence_requests_content_override is enabled)
        long_description: { 'blocks' => [{ 'type' => 'paragraph', 'content' => 'Test description' }] },
        next_steps: { 'blocks' => [{ 'type' => 'paragraph', 'content' => 'Test next steps' }] },
        no_action_needed: false,
        is_dbq: false,
        is_proper_noun: false,
        is_sensitive: false,
        no_provide_prefix: false
      )
    ]
  end

  let(:supporting_documents) do
    [
      BenefitsClaims::Responses::SupportingDocument.new(
        document_id: '{A8A7A709-E3FD-44FA-99C9-C3B772AD0202}',
        document_type_label: 'Photographs',
        original_file_name: 'pension_evidence.pdf',
        tracked_item_id: 529_617,
        upload_date: '2024-10-16'
      )
    ]
  end

  let(:contentions) do
    [
      BenefitsClaims::Responses::Contention.new(
        name: 'Pension claim'
      )
    ]
  end

  let(:events) do
    [
      BenefitsClaims::Responses::Event.new(
        date: '2017-05-02',
        type: 'CLAIM_RECEIVED'
      )
    ]
  end

  let(:issues) do
    [
      BenefitsClaims::Responses::Issue.new(
        active: true,
        description: 'Pension claim',
        diagnostic_code: nil,
        last_action: '2024-10-16',
        date: '2017-05-02'
      )
    ]
  end

  let(:evidence) do
    [
      BenefitsClaims::Responses::Evidence.new(
        date: '2017-05-02',
        description: 'VA Form 21P-527EZ, Application for Pension',
        type: 'VA_FORM'
      )
    ]
  end

  let(:evidence_submissions) do
    [
      BenefitsClaims::Responses::EvidenceSubmission.new(
        acknowledgement_date: '2024-10-16',
        claim_id: 555_555_555,
        created_at: '2024-10-15T10:00:00.000Z',
        delete_date: nil,
        document_type: 'Medical Records',
        failed_date: nil,
        file_name: 'medical_records.pdf',
        id: 12_345,
        lighthouse_upload: true,
        tracked_item_id: 1,
        tracked_item_display_name: 'PMR Pending',
        tracked_item_friendly_name: 'Private Medical Records',
        upload_status: 'SUCCESS',
        va_notify_status: nil
      )
    ]
  end

  let(:valid_params) do
    {
      id: '555555555',
      type: 'claim',
      base_end_product_code: '400',
      claim_date: '2017-05-02',
      claim_phase_dates:,
      claim_type: 'Compensation',
      claim_type_code: '400PREDSCHRG',
      display_title: 'Claim for compensation',
      claim_type_base: 'compensation claim',
      close_date: '2017-10-18',
      decision_letter_sent: false,
      development_letter_sent: false,
      documents_needed: false,
      end_product_code: '404',
      evidence_waiver_submitted5103: false,
      lighthouse_id: nil,
      status: 'COMPLETE',
      supporting_documents:,
      evidence_submissions:,
      contentions:,
      events:,
      issues:,
      evidence:,
      tracked_items:
    }
  end

  describe '#initialize' do
    it 'creates a claim response with valid attributes' do
      claim = described_class.new(valid_params)

      expect(claim.id).to eq('555555555')
      expect(claim.type).to eq('claim')
      expect(claim.base_end_product_code).to eq('400')
      expect(claim.claim_date).to eq('2017-05-02')
      expect(claim.claim_phase_dates).to be_a(BenefitsClaims::Responses::ClaimPhaseDates)
      expect(claim.claim_phase_dates.phase_change_date).to eq('2017-10-18')
      expect(claim.claim_phase_dates.current_phase_back).to be(false)
      expect(claim.claim_phase_dates.phase_type).to eq('COMPLETE')
      expect(claim.claim_phase_dates.latest_phase_type).to eq('COMPLETE')
      expect(claim.claim_phase_dates.previous_phases).to eq({})
      expect(claim.claim_type).to eq('Compensation')
      expect(claim.claim_type_code).to eq('400PREDSCHRG')
      expect(claim.display_title).to eq('Claim for compensation')
      expect(claim.claim_type_base).to eq('compensation claim')
      expect(claim.close_date).to eq('2017-10-18')
      expect(claim.decision_letter_sent).to be(false)
      expect(claim.development_letter_sent).to be(false)
      expect(claim.documents_needed).to be(false)
      expect(claim.end_product_code).to eq('404')
      expect(claim.evidence_waiver_submitted5103).to be(false)
      expect(claim.lighthouse_id).to be_nil
      expect(claim.status).to eq('COMPLETE')
      expect(claim.supporting_documents).to be_an(Array)
      expect(claim.supporting_documents.length).to eq(1)
      expect(claim.supporting_documents.first).to be_a(BenefitsClaims::Responses::SupportingDocument)
      expect(claim.supporting_documents.first.document_id).to eq('{A8A7A709-E3FD-44FA-99C9-C3B772AD0202}')
      expect(claim.supporting_documents.first.document_type_label).to eq('Photographs')
      expect(claim.supporting_documents.first.original_file_name).to eq('pension_evidence.pdf')
      expect(claim.supporting_documents.first.tracked_item_id).to eq(529_617)
      expect(claim.supporting_documents.first.upload_date).to eq('2024-10-16')

      expect(claim.evidence_submissions).to be_an(Array)
      expect(claim.evidence_submissions.length).to eq(1)
      expect(claim.evidence_submissions.first).to be_a(BenefitsClaims::Responses::EvidenceSubmission)
      expect(claim.evidence_submissions.first.acknowledgement_date).to eq('2024-10-16')
      expect(claim.evidence_submissions.first.claim_id).to eq(555_555_555)
      expect(claim.evidence_submissions.first.created_at).to eq('2024-10-15T10:00:00.000Z')
      expect(claim.evidence_submissions.first.delete_date).to be_nil
      expect(claim.evidence_submissions.first.document_type).to eq('Medical Records')
      expect(claim.evidence_submissions.first.failed_date).to be_nil
      expect(claim.evidence_submissions.first.file_name).to eq('medical_records.pdf')
      expect(claim.evidence_submissions.first.id).to eq(12_345)
      expect(claim.evidence_submissions.first.lighthouse_upload).to be(true)
      expect(claim.evidence_submissions.first.tracked_item_id).to eq(1)
      expect(claim.evidence_submissions.first.tracked_item_display_name).to eq('PMR Pending')
      expect(claim.evidence_submissions.first.tracked_item_friendly_name).to eq('Private Medical Records')
      expect(claim.evidence_submissions.first.upload_status).to eq('SUCCESS')
      expect(claim.evidence_submissions.first.va_notify_status).to be_nil

      expect(claim.contentions).to be_an(Array)
      expect(claim.contentions.length).to eq(1)
      expect(claim.contentions.first).to be_a(BenefitsClaims::Responses::Contention)
      expect(claim.contentions.first.name).to eq('Pension claim')

      expect(claim.events).to be_an(Array)
      expect(claim.events.length).to eq(1)
      expect(claim.events.first).to be_a(BenefitsClaims::Responses::Event)
      expect(claim.events.first.date).to eq('2017-05-02')
      expect(claim.events.first.type).to eq('CLAIM_RECEIVED')

      expect(claim.issues).to be_an(Array)
      expect(claim.issues.length).to eq(1)
      expect(claim.issues.first).to be_a(BenefitsClaims::Responses::Issue)
      expect(claim.issues.first.active).to be(true)
      expect(claim.issues.first.description).to eq('Pension claim')
      expect(claim.issues.first.diagnostic_code).to be_nil
      expect(claim.issues.first.last_action).to eq('2024-10-16')
      expect(claim.issues.first.date).to eq('2017-05-02')

      expect(claim.evidence).to be_an(Array)
      expect(claim.evidence.length).to eq(1)
      expect(claim.evidence.first).to be_a(BenefitsClaims::Responses::Evidence)
      expect(claim.evidence.first.date).to eq('2017-05-02')
      expect(claim.evidence.first.description).to eq('VA Form 21P-527EZ, Application for Pension')
      expect(claim.evidence.first.type).to eq('VA_FORM')

      expect(claim.tracked_items).to be_an(Array)
      expect(claim.tracked_items.length).to eq(1)
      expect(claim.tracked_items.first).to be_a(BenefitsClaims::Responses::TrackedItem)
      expect(claim.tracked_items.first.id).to eq(1)
      expect(claim.tracked_items.first.display_name).to eq('PMR Pending')
      expect(claim.tracked_items.first.status).to eq('NEEDED_FROM_YOU')
      expect(claim.tracked_items.first.suspense_date).to eq('2026-12-01')
      expect(claim.tracked_items.first.type).to eq('other')
      expect(claim.tracked_items.first.closed_date).to be_nil
      expect(claim.tracked_items.first.description).to eq('Please submit your private medical records')
      expect(claim.tracked_items.first.overdue).to be(false)
      expect(claim.tracked_items.first.received_date).to be_nil
      expect(claim.tracked_items.first.requested_date).to eq('2024-11-01')
      expect(claim.tracked_items.first.uploads_allowed).to be(true)
      expect(claim.tracked_items.first.uploaded).to be(false)
      expect(claim.tracked_items.first.friendly_name).to eq('Private Medical Records')
      expect(claim.tracked_items.first.friendly_description).to(
        eq('We need your medical records from private providers')
      )
      expect(claim.tracked_items.first.can_upload_file).to be(true)
      expect(claim.tracked_items.first.support_aliases).to eq(['PMR', 'Medical Records'])
      expect(claim.tracked_items.first.documents).to eq('[]')
      expect(claim.tracked_items.first.date).to eq('2024-11-01')
      # New content override fields (populated when cst_evidence_requests_content_override is enabled)
      expect(claim.tracked_items.first.long_description).to eq(
        { 'blocks' => [{ 'type' => 'paragraph', 'content' => 'Test description' }] }
      )
      expect(claim.tracked_items.first.next_steps).to eq(
        { 'blocks' => [{ 'type' => 'paragraph', 'content' => 'Test next steps' }] }
      )
      expect(claim.tracked_items.first.no_action_needed).to be(false)
      expect(claim.tracked_items.first.is_dbq).to be(false)
      expect(claim.tracked_items.first.is_proper_noun).to be(false)
      expect(claim.tracked_items.first.is_sensitive).to be(false)
      expect(claim.tracked_items.first.no_provide_prefix).to be(false)
    end

    it 'defaults type to "claim" if not provided' do
      params = valid_params.except(:type)
      claim = described_class.new(params)

      expect(claim.type).to eq('claim')
    end

    it 'accepts empty evidence_submissions array' do
      params = valid_params.merge(evidence_submissions: [])
      claim = described_class.new(params)

      expect(claim.evidence_submissions).to be_an(Array)
      expect(claim.evidence_submissions).to be_empty
    end

    it 'validates evidence_submissions structure with Hash input' do
      params = valid_params.merge(
        evidence_submissions: [
          {
            acknowledgement_date: '2024-10-17',
            claim_id: 555_555_556,
            created_at: '2024-10-16T10:00:00.000Z',
            delete_date: nil,
            document_type: 'Service Records',
            failed_date: nil,
            file_name: 'dd214.pdf',
            id: 12_346,
            lighthouse_upload: false,
            tracked_item_id: 2,
            tracked_item_display_name: 'Service Records',
            tracked_item_friendly_name: 'DD214',
            upload_status: 'PENDING',
            va_notify_status: 'sent'
          }
        ]
      )
      claim = described_class.new(params)

      expect(claim.evidence_submissions.first).to be_a(BenefitsClaims::Responses::EvidenceSubmission)
      expect(claim.evidence_submissions.first.document_type).to eq('Service Records')
      expect(claim.evidence_submissions.first.file_name).to eq('dd214.pdf')
      expect(claim.evidence_submissions.first.upload_status).to eq('PENDING')
    end

    context 'when array attributes are omitted' do
      let(:claim) { described_class.new({ id: '999', status: 'PENDING' }) }
      let(:array_attributes) do
        %w[supporting_documents evidence_submissions contentions events issues evidence tracked_items]
      end

      it 'defaults all array attributes to empty arrays instead of nil' do
        array_attributes.each do |attr|
          expect(claim.send(attr)).to eq([])
        end
      end

      it 'includes array attributes as empty arrays in serialized output' do
        attributes = claim.attributes

        array_attributes.each do |attr|
          expect(attributes[attr]).to eq([])
          expect(attributes[attr]).not_to be_nil
        end
      end
    end
  end
end
