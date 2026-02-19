# frozen_string_literal: true

require 'rails_helper'
require 'mhv/prescriptions/oh_transition_refill_filter'

RSpec.describe MHV::Prescriptions::OhTransitionRefillFilter do
  subject(:filter) { described_class.new(user) }

  let(:user) { build(:user) }
  let(:mock_oh_helper) { instance_double(MHV::OhFacilitiesHelper::Service) }

  before do
    allow(MHV::OhFacilitiesHelper::Service).to receive(:new).with(user).and_return(mock_oh_helper)
  end

  describe '#partition_orders' do
    let(:orders) do
      [
        { 'stationNumber' => '556', 'id' => '111' },
        { 'stationNumber' => '570', 'id' => '222' }
      ]
    end

    context 'when feature flag is disabled' do
      before do
        allow(Flipper).to receive(:enabled?)
          .with(:mhv_medications_oh_transition_refill_block, user).and_return(false)
      end

      it 'returns all orders as allowed with no blocked failures' do
        allowed, blocked = filter.partition_orders(orders)

        expect(allowed).to eq(orders)
        expect(blocked).to be_empty
      end

      it 'does not call the OH facilities helper' do
        allow(mock_oh_helper).to receive(:get_phases_for_station_numbers)

        filter.partition_orders(orders)

        expect(mock_oh_helper).not_to have_received(:get_phases_for_station_numbers)
      end
    end

    context 'when feature flag is enabled' do
      before do
        allow(Flipper).to receive(:enabled?)
          .with(:mhv_medications_oh_transition_refill_block, user).and_return(true)
      end

      context 'when all facilities are in blocked phases' do
        before do
          allow(mock_oh_helper).to receive(:get_phases_for_station_numbers)
            .with(%w[556 570])
            .and_return({ '556' => 'p5', '570' => 'p4' })
        end

        it 'returns no allowed orders' do
          allowed, _blocked = filter.partition_orders(orders)

          expect(allowed).to be_empty
        end

        it 'returns all orders as blocked failures' do
          _allowed, blocked = filter.partition_orders(orders)

          expect(blocked).to contain_exactly(
            { id: '111', error: described_class::BLOCKED_ERROR_MESSAGE, station_number: '556' },
            { id: '222', error: described_class::BLOCKED_ERROR_MESSAGE, station_number: '570' }
          )
        end
      end

      context 'when some facilities are blocked and some are not' do
        before do
          allow(mock_oh_helper).to receive(:get_phases_for_station_numbers)
            .with(%w[556 570])
            .and_return({ '556' => 'p5', '570' => nil })
        end

        it 'returns non-blocked orders as allowed' do
          allowed, _blocked = filter.partition_orders(orders)

          expect(allowed).to eq([{ 'stationNumber' => '570', 'id' => '222' }])
        end

        it 'returns blocked orders as failures' do
          _allowed, blocked = filter.partition_orders(orders)

          expect(blocked).to eq(
            [{ id: '111', error: described_class::BLOCKED_ERROR_MESSAGE, station_number: '556' }]
          )
        end
      end

      context 'when no facilities are in blocked phases' do
        before do
          allow(mock_oh_helper).to receive(:get_phases_for_station_numbers)
            .with(%w[556 570])
            .and_return({ '556' => 'p3', '570' => 'p7' })
        end

        it 'returns all orders as allowed' do
          allowed, _blocked = filter.partition_orders(orders)

          expect(allowed).to eq(orders)
        end

        it 'returns no blocked failures' do
          _allowed, blocked = filter.partition_orders(orders)

          expect(blocked).to be_empty
        end
      end

      it 'blocks each of the defined blocked phases (p4, p5, p6)' do
        %w[p4 p5 p6].each do |phase|
          allow(mock_oh_helper).to receive(:get_phases_for_station_numbers)
            .and_return({ '556' => phase, '570' => phase })

          _allowed, blocked = filter.partition_orders(orders)

          expect(blocked.length).to eq(2), "Expected phase #{phase} to block both orders"
        end
      end

      it 'does not block phases outside p4-p6' do
        %w[p0 p1 p2 p3 p7].each do |phase|
          allow(mock_oh_helper).to receive(:get_phases_for_station_numbers)
            .and_return({ '556' => phase, '570' => phase })

          allowed, blocked = filter.partition_orders(orders)

          expect(blocked).to be_empty, "Expected phase #{phase} to not block orders"
          expect(allowed.length).to eq(2), "Expected phase #{phase} to allow both orders"
        end
      end

      context 'when a facility has no migration phase (nil)' do
        before do
          allow(mock_oh_helper).to receive(:get_phases_for_station_numbers)
            .with(%w[556 570])
            .and_return({ '556' => nil, '570' => nil })
        end

        it 'allows all orders' do
          allowed, blocked = filter.partition_orders(orders)

          expect(allowed).to eq(orders)
          expect(blocked).to be_empty
        end
      end

      context 'when orders have duplicate station numbers' do
        let(:orders) do
          [
            { 'stationNumber' => '556', 'id' => '111' },
            { 'stationNumber' => '556', 'id' => '222' }
          ]
        end

        before do
          allow(mock_oh_helper).to receive(:get_phases_for_station_numbers)
            .with(%w[556])
            .and_return({ '556' => 'p5' })
        end

        it 'looks up each unique station number only once' do
          filter.partition_orders(orders)

          expect(mock_oh_helper).to have_received(:get_phases_for_station_numbers).with(%w[556]).once
        end

        it 'blocks both orders for the same station' do
          _allowed, blocked = filter.partition_orders(orders)

          expect(blocked.length).to eq(2)
        end
      end

      context 'with empty orders' do
        it 'returns empty arrays' do
          allow(mock_oh_helper).to receive(:get_phases_for_station_numbers)
            .with([]).and_return({})

          allowed, blocked = filter.partition_orders([])

          expect(allowed).to be_empty
          expect(blocked).to be_empty
        end
      end
    end
  end

  describe '.merge_results' do
    let(:api_result) do
      {
        success: [{ id: '222', status: 'submitted', station_number: '570' }],
        failed: [{ id: '333', error: 'upstream error', station_number: '999' }]
      }
    end

    let(:blocked_failures) do
      [{ id: '111', error: described_class::BLOCKED_ERROR_MESSAGE, station_number: '556' }]
    end

    context 'when there are blocked failures' do
      it 'appends blocked failures to the failed list' do
        result = described_class.merge_results(api_result, blocked_failures)

        expect(result[:failed]).to contain_exactly(
          { id: '333', error: 'upstream error', station_number: '999' },
          { id: '111', error: described_class::BLOCKED_ERROR_MESSAGE, station_number: '556' }
        )
      end

      it 'preserves the success list' do
        result = described_class.merge_results(api_result, blocked_failures)

        expect(result[:success]).to eq([{ id: '222', status: 'submitted', station_number: '570' }])
      end
    end

    context 'when there are no blocked failures' do
      it 'returns the api_result unchanged for empty array' do
        result = described_class.merge_results(api_result, [])

        expect(result).to eq(api_result)
      end

      it 'returns the api_result unchanged for nil' do
        result = described_class.merge_results(api_result, nil)

        expect(result).to eq(api_result)
      end
    end

    context 'when api_result has nil success or failed keys' do
      it 'defaults nil success to empty array' do
        result = described_class.merge_results({ success: nil, failed: nil }, blocked_failures)

        expect(result[:success]).to eq([])
        expect(result[:failed]).to eq(blocked_failures)
      end
    end

    context 'when api_result has empty arrays' do
      it 'returns only blocked failures in the failed list' do
        result = described_class.merge_results({ success: [], failed: [] }, blocked_failures)

        expect(result[:success]).to eq([])
        expect(result[:failed]).to eq(blocked_failures)
      end
    end
  end
end
