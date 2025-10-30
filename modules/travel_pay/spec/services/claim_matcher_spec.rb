# frozen_string_literal: true

require 'rails_helper'

describe TravelPay::ClaimMatcher do
  describe '.find_matching_claim' do
    let(:claims) do
      [
        {
          'id' => 'claim1',
          'appointmentDateTime' => '2024-10-17T09:00:00Z',
          'claimStatus' => 'In progress'
        },
        {
          'id' => 'claim2',
          'appointmentDateTime' => '2024-11-10T16:45:00Z',
          'claimStatus' => 'Incomplete'
        }
      ]
    end

    context 'when a matching claim is found' do
      it 'returns the matching claim' do
        appt_start = '2024-10-17T09:00:00Z'
        result = described_class.find_matching_claim(claims, appt_start)

        expect(result).not_to be_nil
        expect(result['id']).to eq('claim1')
      end
    end

    context 'when no matching claim is found' do
      it 'returns nil' do
        appt_start = '2024-12-01T10:00:00Z'
        result = described_class.find_matching_claim(claims, appt_start)

        expect(result).to be_nil
      end
    end

    context 'when claims array is nil' do
      it 'returns nil' do
        result = described_class.find_matching_claim(nil, '2024-10-17T09:00:00Z')

        expect(result).to be_nil
      end
    end

    context 'when claims array is empty' do
      it 'returns nil' do
        result = described_class.find_matching_claim([], '2024-10-17T09:00:00Z')

        expect(result).to be_nil
      end
    end

    context 'when appointment time matches with timezone differences' do
      it 'finds the match by comparing stripped times' do
        appt_start = '2024-11-10T16:45:00+00:00'
        result = described_class.find_matching_claim(claims, appt_start)

        expect(result).not_to be_nil
        expect(result['id']).to eq('claim2')
      end
    end
  end
end
