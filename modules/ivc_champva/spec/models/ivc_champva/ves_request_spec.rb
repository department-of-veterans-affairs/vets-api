# frozen_string_literal: true

require 'rails_helper'

RSpec.describe IvcChampva::VesRequest do
  let(:valid_params) do
    {
      application_type: 'CHAMPVA_APPLICATION',
      sponsor: {
        first_name: 'John',
        last_name: 'Doe',
        ssn: '123456789',
        date_of_birth: '1980-01-01',
        address: {
          street_address: '123 Main St',
          city: 'Anytown',
          state: 'VA',
          zip_code: '12345'
        }
      },
      beneficiaries: [
        {
          first_name: 'Jane',
          last_name: 'Doe',
          ssn: '987654321',
          date_of_birth: '1985-05-15',
          address: {
            street_address: '456 Oak Ave',
            city: 'Somewhere',
            state: 'MD',
            zip_code: '54321'
          }
        }
      ],
      certification: {
        signature: 'John Doe',
        signature_date: '2025-01-01'
      }
    }
  end

  describe '#initialize' do
    it 'initializes with default values' do
      request = described_class.new

      expect(request.application_type).to eq('CHAMPVA')
      expect(request.application_uuid).to be_present
      expect(request.transaction_uuid).to be_present
      expect(request.subforms).to eq([])
    end

    it 'initializes with provided params' do
      request = described_class.new(valid_params)

      expect(request.application_type).to eq('CHAMPVA_APPLICATION')
      expect(request.sponsor.first_name).to eq('John')
      expect(request.beneficiaries.length).to eq(1)
      expect(request.beneficiaries.first.first_name).to eq('Jane')
      expect(request.subforms).to eq([])
    end
  end

  describe '#subforms' do
    it 'initializes as an empty array' do
      request = described_class.new(valid_params)

      expect(request.subforms).to eq([])
      expect(request.subforms).to be_a(Array)
    end
  end

  describe '#add_subform' do
    it 'appends a subform to the subforms array' do
      request = described_class.new(valid_params)
      mock_ohi_request = double('VesOhiRequest', application_uuid: 'test-uuid')

      request.add_subform('vha_10_7959c', mock_ohi_request)

      expect(request.subforms.length).to eq(1)
      expect(request.subforms.first[:form_type]).to eq('vha_10_7959c')
      expect(request.subforms.first[:request]).to eq(mock_ohi_request)
    end

    it 'can add multiple subforms' do
      request = described_class.new(valid_params)
      mock_ohi_request1 = double('VesOhiRequest1')
      mock_ohi_request2 = double('VesOhiRequest2')

      request.add_subform('vha_10_7959c', mock_ohi_request1)
      request.add_subform('vha_10_7959c', mock_ohi_request2)

      expect(request.subforms.length).to eq(2)
    end
  end

  describe '#subforms?' do
    it 'returns false when no subforms exist' do
      request = described_class.new(valid_params)

      expect(request.subforms?).to be(false)
    end

    it 'returns true when subforms exist' do
      request = described_class.new(valid_params)
      mock_ohi_request = double('VesOhiRequest')

      request.add_subform('vha_10_7959c', mock_ohi_request)

      expect(request.subforms?).to be(true)
    end
  end

  describe '#to_json' do
    it 'does NOT include subforms in the JSON output' do
      request = described_class.new(valid_params)
      mock_ohi_request = double('VesOhiRequest')
      request.add_subform('vha_10_7959c', mock_ohi_request)

      json_output = request.to_json
      parsed_json = JSON.parse(json_output)

      expect(parsed_json).not_to have_key('subforms')
      expect(json_output).not_to include('subforms')
    end

    it 'includes all standard VES fields' do
      request = described_class.new(valid_params)

      json_output = request.to_json
      parsed_json = JSON.parse(json_output)

      expect(parsed_json).to have_key('applicationType')
      expect(parsed_json).to have_key('applicationUUID')
      expect(parsed_json).to have_key('sponsor')
      expect(parsed_json).to have_key('beneficiaries')
      expect(parsed_json).to have_key('certification')
      expect(parsed_json).to have_key('transactionUUID')
    end

    it 'returns valid JSON even with subforms attached' do
      request = described_class.new(valid_params)
      mock_ohi_request = double('VesOhiRequest')
      request.add_subform('vha_10_7959c', mock_ohi_request)

      expect { JSON.parse(request.to_json) }.not_to raise_error
    end
  end

  describe 'subform workflow integration' do
    it 'supports the full subform attachment workflow' do
      request = described_class.new(valid_params)

      # Initially no subforms
      expect(request.subforms?).to be(false)

      # Add a subform
      mock_ohi_request = double('VesOhiRequest', application_uuid: request.application_uuid)
      request.add_subform('vha_10_7959c', mock_ohi_request)

      # Now has subforms
      expect(request.subforms?).to be(true)

      # Can iterate subforms
      request.subforms.each do |subform|
        expect(subform[:form_type]).to eq('vha_10_7959c')
        expect(subform[:request]).to eq(mock_ohi_request)
      end

      # JSON still valid and doesn't include subforms
      parsed_json = JSON.parse(request.to_json)
      expect(parsed_json).not_to have_key('subforms')
    end
  end

  describe 'instance_vars_to_hash helper' do
    it 'excludes subforms from hash output' do
      request = described_class.new(valid_params)
      mock_ohi_request = double('VesOhiRequest')
      request.add_subform('vha_10_7959c', mock_ohi_request)

      # Verify subforms exist on the object
      expect(request.subforms.length).to eq(1)

      # But instance_vars_to_hash should exclude it
      hash = instance_vars_to_hash(request)

      expect(hash).not_to have_key(:subforms)
    end
  end
end
