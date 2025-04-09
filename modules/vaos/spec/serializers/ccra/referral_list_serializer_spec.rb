# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Ccra::ReferralListSerializer do
  describe 'serialization' do
    context 'with a list of referrals' do
      # These values should calculate to May 27, 2024
      let(:cardiology_referral) do
        ref = build(
          :ccra_referral_list_entry,
          referral_number: '5682',
          type_of_care: 'CARDIOLOGY',
          start_date: '2024-03-28',
          seoc_days: '60'
        )
        ref.uuid = 'encrypted-5682'
        ref
      end
      let(:podiatry_referral) do
        ref = build(
          :ccra_referral_list_entry,
          referral_number: '5683',
          type_of_care: 'PODIATRY',
          start_date: '2024-03-28',
          seoc_days: '60'
        )
        ref.uuid = 'encrypted-5683'
        ref
      end
      let(:optometry_referral) do
        ref = build(
          :ccra_referral_list_entry,
          referral_number: '5684',
          type_of_care: 'OPTOMETRY',
          start_date: '2024-03-28',
          seoc_days: '60'
        )
        ref.uuid = 'encrypted-5684'
        ref
      end
      let(:referrals) { [cardiology_referral, podiatry_referral, optometry_referral] }
      let(:serializer) { described_class.new(referrals) }
      let(:serialized_data) { serializer.serializable_hash }

      it 'returns a hash with data array' do
        expect(serialized_data).to have_key(:data)
        expect(serialized_data[:data]).to be_an(Array)
        expect(serialized_data[:data].size).to eq(3)
      end

      it 'serializes each referral correctly' do
        expect(serialized_data[:data][0][:id]).to eq('encrypted-5682')
        expect(serialized_data[:data][0][:type]).to eq(:referrals)
        expect(serialized_data[:data][0][:attributes][:typeOfCare]).to eq('CARDIOLOGY')
        expect(serialized_data[:data][0][:attributes][:referralNumber]).to eq('5682')
        expect(serialized_data[:data][0][:attributes][:expirationDate]).to eq('2024-05-27')
        expect(serialized_data[:data][0][:attributes][:uuid]).to eq('encrypted-5682')

        expect(serialized_data[:data][1][:id]).to eq('encrypted-5683')
        expect(serialized_data[:data][1][:type]).to eq(:referrals)
        expect(serialized_data[:data][1][:attributes][:typeOfCare]).to eq('PODIATRY')
        expect(serialized_data[:data][1][:attributes][:referralNumber]).to eq('5683')
        expect(serialized_data[:data][1][:attributes][:expirationDate]).to eq('2024-05-27')
        expect(serialized_data[:data][1][:attributes][:uuid]).to eq('encrypted-5683')

        expect(serialized_data[:data][2][:id]).to eq('encrypted-5684')
        expect(serialized_data[:data][2][:type]).to eq(:referrals)
        expect(serialized_data[:data][2][:attributes][:typeOfCare]).to eq('OPTOMETRY')
        expect(serialized_data[:data][2][:attributes][:referralNumber]).to eq('5684')
        expect(serialized_data[:data][2][:attributes][:expirationDate]).to eq('2024-05-27')
        expect(serialized_data[:data][2][:attributes][:uuid]).to eq('encrypted-5684')
      end
    end

    context 'with an empty list' do
      let(:referrals) { [] }
      let(:serializer) { described_class.new(referrals) }
      let(:serialized_data) { serializer.serializable_hash }

      it 'returns a hash with empty data array' do
        expect(serialized_data).to have_key(:data)
        expect(serialized_data[:data]).to be_an(Array)
        expect(serialized_data[:data]).to be_empty
      end
    end

    context 'with a nil list' do
      let(:referrals) { nil }
      let(:serializer) { described_class.new(referrals) }
      let(:serialized_data) { serializer.serializable_hash }

      it 'returns a hash with empty data array' do
        expect(serialized_data).to have_key(:data)
        expect(serialized_data[:data]).to be_an(Array)
        expect(serialized_data[:data]).to be_empty
      end
    end
  end
end
