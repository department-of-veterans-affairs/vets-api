# frozen_string_literal: true

require 'rails_helper'

RSpec.describe HCA::HealthFacilitiesImportJob, type: :worker do
  describe '#perform' do
    let(:statsd_key_prefix) { HCA::Service::STATSD_KEY_PREFIX }
    let(:mock_get_facilities_page_one) do
      FacilitiesApi::V2::Lighthouse::Response.new(
        {
          'data' => [
            { 'id' => 'vha_635HB', 'attributes' => { 'name' => 'My Fake VA Clinic' } },
            { 'id' => 'vha_463GA', 'attributes' => { 'name' => 'Yet Another Clinic Name' } },
            { 'id' => 'vha_499', 'attributes' => { 'name' => 'My Great New VA Clinic Name' } }
          ],
          'meta' => { 'pagination' => { 'currentPage' => 1, 'perPage' => 1000, 'totalPages' => 2,
                                        'totalEntries' => 4 } }
        }.to_json, 200
      ).facilities
    end

    let(:mock_get_facilities_page_two) do
      FacilitiesApi::V2::Lighthouse::Response.new(
        {
          'data' => [
            { 'id' => 'vha_463GE', 'attributes' => { 'name' => 'My Other Fake VA Clinic' } }
          ],
          'meta' => { 'pagination' => { 'currentPage' => 2, 'perPage' => 2, 'totalPages' => 2, 'totalEntries' => 4 } }
        }.to_json, 200
      ).facilities
    end

    let(:mock_institution_data) do
      [
        { name: 'MY FAKE VA CLINIC', station_number: '635HB', street_state_id: 'AK' },
        { name: 'YET ANOTHER CLINIC NAME', station_number: '463GA', street_state_id: 'OH' },
        { name: 'MY OLD VA CLINIC NAME', station_number: '499', street_state_id: 'NY' },
        { name: 'MY OTHER FAKE VA CLINIC', station_number: '463GE', street_state_id: 'FL' }
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
      create(:health_facility, name: 'My Fake VA Clinic',
                               station_number: mock_institution_data.first[:station_number],
                               postal_name: mock_institution_data.first[:street_state_id])

      # Add existing health_facility record with stale name
      create(:health_facility, name: 'My Old VA Clinic Name',
                               station_number: mock_institution_data.third[:station_number],
                               postal_name: mock_institution_data.third[:street_state_id])

      allow(FacilitiesApi::V2::Lighthouse::Client).to receive(:new).and_return(lighthouse_service)
      allow(lighthouse_service).to receive(:get_facilities)
        .and_return(mock_get_facilities_page_one, mock_get_facilities_page_two)
      allow(Rails.logger).to receive(:info)
      allow(StatsD).to receive(:increment)
    end

    it 'has a retry count of 10' do
      expect(described_class.get_sidekiq_options['retry']).to eq(10)
    end

    context 'success' do
      it 'updates HealthFacilities table without duplicating existing records' do
        expect(Rails.logger).to receive(:info).with(
          '[HCA] - Job started with 2 existing health facilities.'
        )
        expect(Rails.logger).to receive(:info).with(
          '[HCA] - Job ended with 3 health facilities.'
        )

        expect(StatsD).to receive(:increment).with("#{statsd_key_prefix}.health_facilities_import_job_complete")

        expect do
          described_class.new.perform
        end.to change(HealthFacility, :count).by(1)

        station_numbers = mock_institution_data.map { |institution| institution[:station_number] }
        expect(HealthFacility
          .where(station_number: station_numbers)
          .pluck(:name)).to contain_exactly(
            'My Fake VA Clinic',
            'Yet Another Clinic Name',
            'My Great New VA Clinic Name' # Validates name is updated from Lighthouse api response
          )
      end

      context 'pagination' do
        mock_per_page = 2
        before { stub_const("#{described_class}::PER_PAGE", mock_per_page) }

        it 'fetches multiple pages of facilities' do
          expect(lighthouse_service).to receive(:get_facilities).with(type: 'health', per_page: mock_per_page,
                                                                      page: 1).and_return(mock_get_facilities_page_one)
          expect(lighthouse_service).to receive(:get_facilities).with(type: 'health', per_page: mock_per_page,
                                                                      page: 2).and_return(mock_get_facilities_page_two)

          expect do
            described_class.new.perform
          end.to change(HealthFacility, :count).by(2)

          # Verify the correct facilities are added
          expect(HealthFacility.pluck(:name)).to contain_exactly(
            'My Fake VA Clinic',
            'Yet Another Clinic Name',
            'My Great New VA Clinic Name',
            'My Other Fake VA Clinic'
          )
        end
      end
    end

    context 'error' do
      it 'logs errors when API call fails' do
        expect(lighthouse_service).to receive(:get_facilities).and_raise(StandardError, 'something broke')
        expect(Rails.logger).to receive(:info).with(
          '[HCA] - Job started with 2 existing health facilities.'
        )
        expect(Rails.logger).to receive(:error).with(
          "[HCA] - Error occurred in #{described_class.name}: something broke"
        )
        expect do
          described_class.new.perform
        end.to raise_error(RuntimeError, "Failed to import health facilities in #{described_class.name}")
      end

      describe 'when retries are exhausted' do
        it 'logs error and increments StatsD' do
          described_class.within_sidekiq_retries_exhausted_block do
            expect(Rails.logger).to receive(:error).with(
              "[HCA] - #{described_class.name} failed with no retries left."
            )
            expect(StatsD).to receive(:increment).with(
              "#{statsd_key_prefix}.health_facilities_import_job_failed_no_retries"
            )
          end
        end
      end
    end

    context 'std_states table is empty' do
      before do
        StdState.destroy_all
      end

      it 'enqueues IncomeLimits::StdStateImport and raises error' do
        expect(Rails.logger).to receive(:info).with(
          '[HCA] - Job started with 2 existing health facilities.'
        )
        expect(Rails.logger).to receive(:error).with(
          "[HCA] - Error occurred in #{described_class.name}: StdStates missing – triggered import and retrying job"
        )

        import_job = instance_double(IncomeLimits::StdStateImport)
        expect(IncomeLimits::StdStateImport).to receive(:new).and_return(import_job)
        expect(import_job).to receive(:perform)

        expect do
          described_class.new.perform
        end.to raise_error(RuntimeError, "Failed to import health facilities in #{described_class.name}")
      end
    end
  end
end
