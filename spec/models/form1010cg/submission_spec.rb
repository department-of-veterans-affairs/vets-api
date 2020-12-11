# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Form1010cg::Submission, type: :model do
  let(:sample_data) do
    {
      carma_case_id: 'aB9r00000004GW9CAK',
      accepted_at: DateTime.now.iso8601,
      attachments: {
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
      },
      metadata: {
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
    }
  end

  it 'can initialize with attributes :carma_case_id, :accepted_at, :attachments, :metadata' do
    instance_1 = described_class.new
    expect(instance_1.carma_case_id).to eq(nil)
    expect(instance_1.accepted_at).to eq(nil)
    expect(instance_1.attachments).to eq(nil)
    expect(instance_1.metadata).to eq(nil)

    instance_2 = described_class.new(sample_data)
    expect(instance_2.carma_case_id).to eq(sample_data[:carma_case_id])
    expect(instance_2.accepted_at).to eq(sample_data[:accepted_at])
    expect(instance_2.attachments).to eq(sample_data[:attachments].deep_stringify_keys)
    expect(instance_2.metadata).to eq(sample_data[:metadata].deep_stringify_keys)
  end

  it 'has attribute accessors for :carma_case_id, :accepted_at, :attachments, :metadata' do
    expect(subject.carma_case_id).to eq(nil)
    expect(subject.accepted_at).to eq(nil)
    expect(subject.attachments).to eq(nil)
    expect(subject.metadata).to eq(nil)

    subject.carma_case_id = sample_data[:carma_case_id]
    subject.accepted_at = sample_data[:accepted_at]
    subject.attachments = sample_data[:attachments]
    subject.metadata = sample_data[:metadata]

    expect(subject.carma_case_id).to eq(sample_data[:carma_case_id])
    expect(subject.accepted_at).to eq(sample_data[:accepted_at])
    expect(subject.attachments).to eq(sample_data[:attachments].deep_stringify_keys)
    expect(subject.metadata).to eq(sample_data[:metadata].deep_stringify_keys)
  end
end
