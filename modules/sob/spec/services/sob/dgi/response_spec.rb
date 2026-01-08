# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SOB::DGI::Response do
  subject(:response) { described_class.new(raw_response.status, raw_response) }

  let(:claimant) { File.read('modules/sob/spec/fixtures/claimant.json') }
  let(:body) { JSON.parse(claimant).deep_transform_keys!(&:underscore) }
  let(:raw_response) { instance_double(Faraday::Env, status: 200, body:) }
  let(:attributes) do
    {
      'first_name' => 'Jane',
      'last_name' => 'Smith',
      'date_of_birth' => '1988-03-01',
      'va_file_number' => '123456789',
      'regional_processing_office' => 'Muskogee, OK',
      'active_duty' => true,
      'veteran_is_eligible' => true,
      'eligibility_date' => '2005-04-01',
      'delimiting_date' => nil,
      'percentage_benefit' => 100,
      'original_entitlement' => {
        'months' => 36,
        'days' => 0
      },
      'used_entitlement' => {
        'months' => 22,
        'days' => 3
      },
      'remaining_entitlement' => {
        'months' => 0,
        'days' => 0
      },
      'entitlement_transferred_out' => {
        'months' => 14,
        'days' => 10
      }
    }
  end

  describe '#initialize' do
    it 'parses response body and sets attributes' do
      expect(response.attributes).to eq(attributes)
    end

    it 'aggregates TOEs across transfers to multiple dependents' do
      toes = body['claimant']['benefits'].first['entitlement_transfer_out']
      total_days = toes.sum { |toe| toe['transferred_days'] }
      transferred_out = response.entitlement_transferred_out
      expect(total_days).to eq((transferred_out.months * 30) + transferred_out.days)
    end

    context 'when no entitlement transferred out' do
      it 'sets months and days to zero' do
        body['claimant']['benefits'].first['entitlement_transfer_out'] = []
        expect(response.entitlement_transferred_out).to eq({ months: 0, days: 0 })
      end
    end

    context 'when no Ch 33 benefit present' do
      it 'throws Ch33DataMissing error' do
        body['claimant']['benefits'] = []
        expect { response }.to raise_error(described_class::Ch33DataMissing)
      end
    end
  end
end
