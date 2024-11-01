# frozen_string_literal: true

require 'rails_helper'
require_relative '../../rails_helper'

describe ClaimsApi::DocumentServiceBase do
  subject { described_class.new }

  let(:claim_id) { '581128c6-ad08-4b1e-8b82-c3640e829fb3' }
  let(:file_number) { '123456789' }
  let(:participant_id) { '987654321' }
  let(:dependent_veteran_name) { 'margie_curtis' }
  let(:ews_suffix) { '5103' }

  let(:ews_doc_type) { 'L705' }
  let(:dis_comp_doc_type) { 'L122' }
  let(:correspondence_doc_type) { 'L023' }

  describe '#build_body' do
    it 'builds an L122 (526) body correctly' do
      result = subject.send(:build_body, system_name: 'VA.gov', doc_type: dis_comp_doc_type,
                                         file_name: '21-526EZ.pdf', claim_id:, file_number:)

      expected = { data: { systemName: 'VA.gov', docType: dis_comp_doc_type, claimId: claim_id,
                           fileName: '21-526EZ.pdf', trackedItemIds: [], fileNumber: '123456789' } }
      expect(result).to eq(expected)
    end

    it 'builds an L023 (correspondence) body correctly' do
      result = subject.send(:build_body, system_name: 'VA.gov', doc_type: correspondence_doc_type,
                                         file_name: 'rx.pdf', claim_id:, file_number:)

      expected = { data: { systemName: 'VA.gov', docType: correspondence_doc_type, claimId: claim_id,
                           fileName: 'rx.pdf', trackedItemIds: [], fileNumber: '123456789' } }
      expect(result).to eq(expected)
    end

    it 'builds an L075 (POA) body correctly' do
      result = subject.send(:build_body, system_name: 'Lighthouse', doc_type: 'L075', file_name: 'temp_2122.pdf',
                                         claim_id: nil, participant_id:)

      expected = { data: { systemName: 'Lighthouse', docType: 'L075',
                           fileName: 'temp_2122.pdf', trackedItemIds: [], participantId: '987654321' } }
      expect(result).to eq(expected)
    end

    it 'builds an L190 (POA) body correctly' do
      result = subject.send(:build_body, system_name: 'Lighthouse', doc_type: 'L190', file_name: 'temp_2122.pdf',
                                         claim_id: nil, participant_id:)

      expected = { data: { systemName: 'Lighthouse', docType: 'L190',
                           fileName: 'temp_2122.pdf', trackedItemIds: [], participantId: '987654321' } }
      expect(result).to eq(expected)
    end

    it 'builds an L705 (EWS) body correctly' do
      result = subject.send(:build_body, system_name: 'VA.gov', doc_type: ews_doc_type, file_name: 'temp_5103.pdf',
                                         claim_id:, participant_id:)

      expected = { data: { systemName: 'VA.gov', docType: ews_doc_type, claimId: claim_id,
                           fileName: 'temp_5103.pdf', trackedItemIds: [], participantId: '987654321' } }
      expect(result).to eq(expected)
    end

    it 'builds an L705 (EWS) file name correctly for a dependent claimant' do
      result = subject.send(:build_file_name, veteran_name: dependent_veteran_name, identifier: claim_id,
                                              suffix: ews_suffix, dependent: true)
      expected_file_name = "dependent_#{dependent_veteran_name}_#{claim_id}_5103.pdf"

      expect(result).to eq(expected_file_name)
    end
  end
end
