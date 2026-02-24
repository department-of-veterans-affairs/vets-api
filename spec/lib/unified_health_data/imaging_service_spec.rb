# frozen_string_literal: true

require 'rails_helper'
require 'unified_health_data/imaging_service'

describe UnifiedHealthData::ImagingService, type: :service do
  let(:user) { build(:user, :loa3, icn: '1000123456V123456') }
  let(:service) { described_class.new(user) }
  let(:adapter) { instance_double(UnifiedHealthData::Adapters::ImagingStudyAdapter) }
  let(:client) { instance_double(UnifiedHealthData::Client) }
  let(:parsed_studies) { [instance_double(UnifiedHealthData::ImagingStudy)] }

  let(:date_params) { { start_date: '2024-01-01', end_date: '2025-01-01' } }

  before do
    allow(UnifiedHealthData::Client).to receive(:new).and_return(client)
    allow(UnifiedHealthData::Adapters::ImagingStudyAdapter).to receive(:new).and_return(adapter)
    allow(adapter).to receive(:parse).and_return(parsed_studies)
  end

  describe '#get_imaging_studies' do
    let(:response) do
      Faraday::Response.new(body: {
                              'resourceType' => 'Bundle',
                              'entry' => []
                            })
    end

    before do
      allow(client).to receive(:get_imaging_studies).and_return(response)
    end

    it 'calls the client with the correct params' do
      service.get_imaging_studies(**date_params, imaging_study_type: 'CT', site_ids: %w[200CRNR 123])

      expect(client).to have_received(:get_imaging_studies).with(
        patient_id: user.icn,
        start_date: '2024-01-01',
        end_date: '2025-01-01',
        imaging_study_type: 'CT',
        site_ids: %w[200CRNR 123]
      )
    end

    it 'defaults imaging_study_type to ALL and site_ids to empty' do
      service.get_imaging_studies(**date_params)

      expect(client).to have_received(:get_imaging_studies).with(
        patient_id: user.icn,
        start_date: '2024-01-01',
        end_date: '2025-01-01',
        imaging_study_type: 'ALL',
        site_ids: []
      )
    end

    it 'passes flat entry records to the adapter for parsing' do
      entry1 = { 'resource' => { 'resourceType' => 'ImagingStudy', 'id' => 'study-1' } }
      entry2 = { 'resource' => { 'resourceType' => 'ImagingStudy', 'id' => 'study-2' } }
      flat_response = Faraday::Response.new(body: {
                                              'resourceType' => 'Bundle',
                                              'entry' => [entry1, entry2]
                                            })
      allow(client).to receive(:get_imaging_studies).and_return(flat_response)

      service.get_imaging_studies(**date_params)

      expect(adapter).to have_received(:parse).with([entry1, entry2])
    end

    it 'parses the response entries through the adapter' do
      result = service.get_imaging_studies(**date_params)

      expect(adapter).to have_received(:parse).with([])
      expect(result).to eq(parsed_studies)
    end
  end

  describe '#get_imaging_study' do
    let(:response) { Faraday::Response.new(body: { 'entry' => [] }) }

    before do
      allow(client).to receive(:get_imaging_study).and_return(response)
    end

    it 'calls the client with the correct params' do
      service.get_imaging_study(**date_params, record_id: 'study-123')

      expect(client).to have_received(:get_imaging_study).with(
        patient_id: user.icn,
        start_date: '2024-01-01',
        end_date: '2025-01-01',
        record_id: 'study-123'
      )
    end

    it 'parses the response entries through the adapter' do
      result = service.get_imaging_study(**date_params, record_id: 'study-123')

      expect(adapter).to have_received(:parse).with(response.body['entry'])
      expect(result).to eq(parsed_studies)
    end
  end

  describe '#get_dicom_zip' do
    let(:response) { Faraday::Response.new(body: { 'entry' => [] }) }

    before do
      allow(client).to receive(:get_dicom_zip).and_return(response)
    end

    it 'calls the client with the correct params' do
      service.get_dicom_zip(**date_params, record_id: 'study-456')

      expect(client).to have_received(:get_dicom_zip).with(
        patient_id: user.icn,
        start_date: '2024-01-01',
        end_date: '2025-01-01',
        record_id: 'study-456'
      )
    end

    it 'parses the response entries through the adapter' do
      result = service.get_dicom_zip(**date_params, record_id: 'study-456')

      expect(adapter).to have_received(:parse).with(response.body['entry'])
      expect(result).to eq(parsed_studies)
    end
  end
end
