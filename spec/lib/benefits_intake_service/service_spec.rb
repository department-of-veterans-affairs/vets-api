# frozen_string_literal: true

require 'rails_helper'
require 'benefits_intake_service/service'

RSpec.describe BenefitsIntakeService::Service do
  let(:job) { described_class.new }

  describe 'generate_metadata' do
    it 'submits metadata with invalid characters and validates' do
      metadata = {
        veteran_first_name: 'te`st',
        veteran_last_name: 'last name',
        file_number: '987654321',
        zip: '20007',
        source: 'va.gov backup submission',
        doc_type: '686C-674',
        business_line: 'CMP',
        claim_date: Date.new(2024, 7, 31)
      }

      expected_response = {
        'veteranFirstName' => 'test',
        'veteranLastName' => 'last name',
        'fileNumber' => '987654321',
        'zipCode' => '20007',
        'source' => 'va.gov backup submission',
        'docType' => '686C-674',
        'businessLine' => 'CMP',
        'claimDate' => Date.new(2024, 7, 31)
      }
      expect(job.generate_metadata(metadata)).to eq(expected_response)
    end
  end
end
