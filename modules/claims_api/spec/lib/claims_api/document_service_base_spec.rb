# frozen_string_literal: true

require 'rails_helper'
require_relative '../../rails_helper'

describe ClaimsApi::DocumentServiceBase do
  subject { described_class.new }

  let(:claim_id) { '581128c6-ad08-4b1e-8b82-c3640e829fb3' }

  describe '#build_body' do
    it 'builds an L122 (526) body correctly' do
      result = subject.send(:build_body, system_name: 'VA.gov', doc_type: 'L122', file_name: '21-526EZ.pdf', claim_id:)

      expected = { data: { systemName: 'VA.gov', docType: 'L122', claimId: '581128c6-ad08-4b1e-8b82-c3640e829fb3',
                           fileName: '21-526EZ.pdf', trackedItemIds: [] } }
      expect(result).to eq(expected)
    end

    it 'builds an L023 (correspondence) body correctly' do
      result = subject.send(:build_body, system_name: 'VA.gov', doc_type: 'L023', file_name: 'rx.pdf', claim_id:)

      expected = { data: { systemName: 'VA.gov', docType: 'L023', claimId: '581128c6-ad08-4b1e-8b82-c3640e829fb3',
                           fileName: 'rx.pdf', trackedItemIds: [] } }
      expect(result).to eq(expected)
    end
  end
end
