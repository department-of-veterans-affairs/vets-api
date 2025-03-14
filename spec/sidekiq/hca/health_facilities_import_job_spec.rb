# frozen_string_literal: true

require 'rails_helper'

RSpec.describe HCA::HealthFacilitiesImportJob, type: :worker do
  describe '#perform' do
    let(:mock_facility_ids_response) do
      FacilitiesApi::V2::Lighthouse::Response.new({
        'data' =>
          %w[vha_635HB vha_463GA vha_463GE]
      }.to_json, 200)
    end

    let(:mock_institution_data) do
      [
        { name: 'My Fake Clinic', station_number: '635HB', street_state_id: 'AK' },
        { name: 'Yet Another Clinic Name', station_number: '463GA', street_state_id: 'OH' },
        { name: 'My Other Fake Clinic', station_number: '463GE', street_state_id: 'FL' }
      ]
    end

    let(:lighthouse_service) { double('FacilitiesApi::V2::Lighthouse::Client') }

    before do
      # Setup std_state and std_institution data
      mock_institution_data.each_with_index do |institution, i|
        street_state_id = i + 1
        create(:std_state, postal_name: institution[:street_state_id], id: street_state_id)
        create(:std_institution_facility, name: institution[:name],
                                          station_number: institution[:station_number],
                                          street_state_id:)
      end

      # Add existing health_facility record
      create(:health_facility, name: mock_institution_data.first[:name],
                               station_number: mock_institution_data.first[:station_number],
                               postal_name: mock_institution_data.first[:street_state_id])

      allow(FacilitiesApi::V2::Lighthouse::Client).to receive(:new).and_return(lighthouse_service)
      allow(lighthouse_service).to receive(:get_facility_ids).and_return(mock_facility_ids_response)
      allow(Rails.logger).to receive(:info)
    end

    context 'success' do
      it 'populates HealthFacilities without duplicating existing records' do
        expect(Rails.logger).to receive(:info).with(
          'Job started with 1 existing health facilities.'
        )
        expect(Rails.logger).to receive(:info).with(
          'Job ended with 3 health facilities.'
        )
        expect do
          described_class.new.perform
        end.to change(HealthFacility, :count).by(2)

        station_numbers = mock_institution_data.map { |institution| institution[:station_number] }
        expect(HealthFacility.where(station_number: station_numbers).pluck(:station_number).count).to eq 3
      end
    end

    context 'error' do
      it 'logs errors when api call fails' do
        expect(lighthouse_service).to receive(:get_facility_ids).and_raise(StandardError,
                                                                           'something broke')
        expect(Rails.logger).to receive(:info).with(
          'Job started with 1 existing health facilities.'
        )
        expect(Rails.logger).to receive(:error).with(
          "Error occurred in #{described_class.name}: something broke"
        )
        expect do
          described_class.new.perform
        end.to raise_error(RuntimeError, "Failed to import health facilities in #{described_class.name}")
      end
    end
  end
end
