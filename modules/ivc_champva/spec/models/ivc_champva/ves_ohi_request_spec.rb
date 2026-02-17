# frozen_string_literal: true

require 'rails_helper'

RSpec.describe IvcChampva::VesOhiRequest do
  # TODO: Expand coverage after VES swagger spec is available
  describe 'FORM_TYPE' do
    it 'returns vha_10_7959c' do
      expect(described_class::FORM_TYPE).to eq('vha_10_7959c')
    end
  end

  describe '#initialize' do
    it 'generates UUIDs when not provided' do
      request = described_class.new
      expect(request.application_uuid).to match(/\A[0-9a-f-]{36}\z/)
      expect(request.transaction_uuid).to match(/\A[0-9a-f-]{36}\z/)
    end

    it 'uses provided UUIDs' do
      request = described_class.new(application_uuid: 'app-123', transaction_uuid: 'trans-456')
      expect(request.application_uuid).to eq('app-123')
      expect(request.transaction_uuid).to eq('trans-456')
    end

    it 'initializes nested objects' do
      request = described_class.new(
        beneficiary: { first_name: 'Jane' },
        medicare: [{ plan_type: 'c' }],
        health_insurance: [{ provider: 'Aetna' }],
        certification: { signature: 'Jane Doe' }
      )

      expect(request.beneficiary.first_name).to eq('Jane')
      expect(request.medicare.first.plan_type).to eq('c')
      expect(request.health_insurance.first.provider).to eq('Aetna')
      expect(request.certification.signature).to eq('Jane Doe')
    end
  end

  describe '#form_type' do
    it 'returns FORM_TYPE constant' do
      expect(described_class.new.form_type).to eq('vha_10_7959c')
    end
  end

  describe '#to_json' do
    it 'serializes to valid JSON with camelCase keys' do
      request = described_class.new(
        application_uuid: 'app-uuid',
        transaction_uuid: 'trans-uuid',
        person_uuid: 'person-uuid',
        beneficiary: { first_name: 'Jane', last_name: 'Doe' },
        medicare: [{ plan_type: 'ab' }],
        health_insurance: [{ provider: 'Blue Cross' }],
        certification: { signature: 'Jane Doe' }
      )

      json = JSON.parse(request.to_json)

      expect(json['applicationUUID']).to eq('app-uuid')
      expect(json['transactionUUID']).to eq('trans-uuid')
      expect(json['personUUID']).to eq('person-uuid')
      expect(json['beneficiary']['firstName']).to eq('Jane')
      expect(json['medicare'].first['planType']).to eq('ab')
      expect(json['healthInsurance'].first['provider']).to eq('Blue Cross')
      expect(json['certification']['signature']).to eq('Jane Doe')
    end

    it 'excludes nil values' do
      request = described_class.new(application_uuid: 'app-uuid')
      json = JSON.parse(request.to_json)

      expect(json).not_to have_key('personUUID')
    end
  end
end
