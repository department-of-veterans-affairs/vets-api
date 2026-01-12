# frozen_string_literal: true

require 'rails_helper'
require 'lighthouse/facilities/v1/client'

RSpec.describe UserVisnService do
  let(:user) { build(:user) }
  let(:facility_ids) { %w[402 515 635] }
  let(:service) { described_class.new(user) }

  before do
    allow(user).to receive(:va_treatment_facility_ids).and_return(facility_ids)
  end

  describe 'PILOT_VISNS constant' do
    let(:pilot_visns) do
      %w[2 15 21 20 10 19]
    end

    it 'contains the expected pilot VISNs' do
      expect(described_class::PILOT_VISNS).to eq(pilot_visns)
    end

    it 'is frozen' do
      expect(described_class::PILOT_VISNS).to be_frozen
    end
  end

  describe 'CACHE_KEY_PREFIX constant' do
    it 'has the expected prefix' do
      expect(described_class::CACHE_KEY_PREFIX).to eq('va_profile:facility_visn')
    end
  end

  describe '#initialize' do
    it 'stores the user' do
      expect(service.instance_variable_get(:@user)).to eq(user)
    end
  end

  describe '#in_pilot_visn?' do
    context 'when user has no treatment facilities' do
      let(:facility_ids) { [] }

      it 'returns false' do
        expect(service.in_pilot_visn?).to be false
      end
    end

    context 'when user has treatment facilities' do
      before do
        # Stubbing the external API calls to control return values
        allow(service).to receive(:get_cached_visn_for_facility).with('402').and_return('2')  # Pilot VISN
        allow(service).to receive(:get_cached_visn_for_facility).with('515').and_return('15') # Pilot VISN
        allow(service).to receive(:get_cached_visn_for_facility).with('635').and_return('6')  # Non-pilot VISN
      end

      context 'when user has facilities in pilot VISNs' do
        it 'returns true' do
          expect(service.in_pilot_visn?).to be true
        end
      end

      context 'when user has facilities only in non-pilot VISNs' do
        let(:facility_ids) { %w[635 756] }

        before do
          allow(service).to receive(:get_cached_visn_for_facility).with('635').and_return('6')
          allow(service).to receive(:get_cached_visn_for_facility).with('756').and_return('7')
        end

        it 'returns false' do
          expect(service.in_pilot_visn?).to be false
        end
      end

      context 'when some facility VISN lookups fail' do
        let(:facility_ids) { %w[402 999] }

        before do
          allow(service).to receive(:get_cached_visn_for_facility).with('402').and_return('2')
          allow(service).to receive(:get_cached_visn_for_facility).with('999').and_return(nil)
        end

        it 'returns true if any successful lookup is a pilot VISN' do
          expect(service.in_pilot_visn?).to be true
        end
      end

      context 'when all facility VISN lookups fail' do
        let(:facility_ids) { %w[999 888] }

        before do
          allow(service).to receive(:get_cached_visn_for_facility).with('999').and_return(nil)
          allow(service).to receive(:get_cached_visn_for_facility).with('888').and_return(nil)
        end

        it 'returns false' do
          expect(service.in_pilot_visn?).to be false
        end
      end
    end
  end

  describe '#get_cached_visn_for_facility' do
    let(:facility_id) { '402' }
    let(:cache_key) { "va_profile:facility_visn:#{facility_id}" }
    let(:expected_visn) { '2' }

    context 'when VISN is cached' do
      before do
        # Mock Rails.cache.fetch to return cached value without calling block
        allow(Rails.cache).to receive(:fetch).with(cache_key, expires_in: 24.hours).and_return(expected_visn)
      end

      it 'returns cached value without calling Lighthouse API' do
        expect_any_instance_of(Lighthouse::Facilities::V1::Client).not_to receive(:get_facilities)
        result = service.send(:get_cached_visn_for_facility, facility_id)
        expect(result).to eq(expected_visn)
      end
    end

    context 'when VISN is not cached' do
      let(:facility_mock) { double('facility', attributes: { 'visn' => 2 }) }

      before do
        # Mock Rails.cache.fetch to call the block (cache miss)
        allow(Rails.cache).to receive(:fetch).with(cache_key, expires_in: 24.hours).and_yield

        # Mock the actual Lighthouse call
        allow_any_instance_of(Lighthouse::Facilities::V1::Client).to receive(:get_facilities)
          .with(facilityIds: "vha_#{facility_id}")
          .and_return([facility_mock])
      end

      it 'calls Lighthouse API and returns result' do
        expect_any_instance_of(Lighthouse::Facilities::V1::Client).to receive(:get_facilities)
          .with(facilityIds: "vha_#{facility_id}")
          .once
        result = service.send(:get_cached_visn_for_facility, facility_id)
        expect(result).to eq(expected_visn)
      end
    end
  end

  describe '#fetch_visn_from_lighthouse' do
    let(:facility_id) { '402' }
    let(:lighthouse_client) { instance_double(Lighthouse::Facilities::V1::Client) }
    let(:attributes) { { 'visn' => 2 } }
    let(:result) { service.send(:fetch_visn_from_lighthouse, facility_id) }

    before do
      allow(Lighthouse::Facilities::V1::Client).to receive(:new).and_return(lighthouse_client)
    end

    context 'when Lighthouse API call succeeds' do
      let(:facility_mock) { double('facility', attributes:) }

      before do
        allow(lighthouse_client)
          .to receive(:get_facilities)
          .with(facilityIds: "vha_#{facility_id}")
          .and_return([facility_mock])
      end

      it 'returns VISN as string' do
        expect(result).to eq('2')
      end

      context 'when VISN is nil' do
        let(:attributes) { { 'visn' => nil } }

        it 'returns nil' do
          expect(result).to be_nil
        end
      end

      context 'when VISN is missing from attributes' do
        let(:attributes) { {} }

        it 'returns nil' do
          expect(result).to be_nil
        end
      end
    end

    context 'when facility response is empty' do
      before do
        allow(lighthouse_client).to receive(:get_facilities).with(facilityIds: "vha_#{facility_id}").and_return([])
      end

      it 'returns nil' do
        expect(result).to be_nil
      end
    end

    context 'when facility has no attributes' do
      let(:facility_mock) { double('facility', attributes: nil) }

      before do
        allow(lighthouse_client)
          .to receive(:get_facilities)
          .with(facilityIds: "vha_#{facility_id}")
          .and_return([facility_mock])
      end

      it 'returns nil' do
        expect(result).to be_nil
      end
    end

    context 'when API call raises an exception' do
      let(:error_message) { 'Lighthouse API error' }

      before do
        allow(lighthouse_client).to receive(:get_facilities).and_raise(StandardError, error_message)
        allow(Rails.logger).to receive(:warn)
      end

      it 'logs warning and returns nil' do
        expect(Rails.logger)
          .to receive(:warn)
          .with("Failed to fetch VISN for facility #{facility_id}: #{error_message}")
        expect(result).to be_nil
      end
    end
  end

  describe 'integration scenarios' do
    before do
      Rails.cache.clear
    end

    context 'real integration with mocked Lighthouse responses' do
      let(:facility_ids) { %w[402 515 635] }

      before do
        allow_any_instance_of(Lighthouse::Facilities::V1::Client).to receive(:get_facilities) do |_client, params|
          facility_id = params[:facilityIds]
          case facility_id
          when 'vha_402'
            [double('facility', attributes: { 'visn' => 2 })]
          when 'vha_515'
            [double('facility', attributes: { 'visn' => 15 })]
          when 'vha_635'
            [double('facility', attributes: { 'visn' => 6 })]
          else
            []
          end
        end
      end

      it 'correctly identifies pilot users through full flow' do
        expect(service.in_pilot_visn?).to be true
      end
    end
  end
end
