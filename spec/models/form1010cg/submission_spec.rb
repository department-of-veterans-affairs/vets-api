# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Form1010cg::Submission, type: :model do
  it 'has attribute accessors for :carma_case_id, :submitted_at, :attachments, :metadata' do
    expect(subject.carma_case_id).to eq(nil)
    expect(subject.submitted_at).to eq(nil)
    expect(subject.attachments).to eq({})
    expect(subject.metadata).to eq(nil)

    carma_case_id = 'aB9r00000004GW9CAK'
    submitted_at = DateTime.now.iso8601
    attachments = {
      has_errors: false,
      data: [
        {
          id: '06835000000YpsjAAC',
          carma_case_id: 'aB9r00000004GW9CAK',
          veteran_name: {
            first: 'Jane',
            last: 'Doe'
          },
          file_path: '10-10CG_123456.pdf',
          document_type: '10-10CG',
          document_date: '2020-03-30'
        }
      ]
    }
    metadata = {
      'claimId' => nil,
      'claimGuid' => 'uuid-1234',
      'veteran' => {
        'icn' => 'ICN_123',
        'isVeteran' => true
      },
      'primaryCaregiver' => {
        'icn' => nil
      },
      'secondaryCaregiverOne' => nil,
      'secondaryCaregiverTwo' => nil
    }

    expect(subject.carma_case_id).to eq(carma_case_id)
    expect(subject.submitted_at).to eq(submitted_at)
    expect(subject.attachments).to eq(attachments)
    expect(subject.metadata).to eq(metadata)
  end
end
