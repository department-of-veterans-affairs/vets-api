# frozen_string_literal: true

require 'rails_helper'
require_relative '../../rails_helper'

describe ClaimsApi::DocumentServiceBase do
  subject { described_class.new }

  let(:claim_id) { '581128c6-ad08-4b1e-8b82-c3640e829fb3' }
  let(:file_number) { '123456789' }
  let(:participant_id) { '987654321' }

  describe '#build_body' do
    it 'builds an L122 (526) body correctly' do
      result = subject.send(:build_body, system_name: 'VA.gov', doc_type: 'L122', file_name: '21-526EZ.pdf', claim_id:,
                                         file_number:)

      expected = { data: { systemName: 'VA.gov', docType: 'L122', claimId: '581128c6-ad08-4b1e-8b82-c3640e829fb3',
                           fileName: '21-526EZ.pdf', trackedItemIds: [], fileNumber: '123456789' } }
      expect(result).to eq(expected)
    end

    it 'builds an L023 (correspondence) body correctly' do
      result = subject.send(:build_body, system_name: 'VA.gov', doc_type: 'L023', file_name: 'rx.pdf', claim_id:,
                                         file_number:)

      expected = { data: { systemName: 'VA.gov', docType: 'L023', claimId: '581128c6-ad08-4b1e-8b82-c3640e829fb3',
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
      result = subject.send(:build_body, system_name: 'VA.gov', doc_type: 'L705', file_name: 'temp_5103.pdf',
                                         claim_id:, participant_id:)

      expected = { data: { systemName: 'VA.gov', docType: 'L705', claimId: '581128c6-ad08-4b1e-8b82-c3640e829fb3',
                           fileName: 'temp_5103.pdf', trackedItemIds: [], participantId: '987654321' } }
      expect(result).to eq(expected)
    end
  end
end
