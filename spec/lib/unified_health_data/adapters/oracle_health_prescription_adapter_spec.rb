# frozen_string_literal: true

require 'rails_helper'
require 'unified_health_data/models/prescription'
require 'unified_health_data/adapters/oracle_health_prescription_adapter'
require 'lighthouse/facilities/v1/client'

describe UnifiedHealthData::Adapters::OracleHealthPrescriptionAdapter do
  subject { described_class.new }

  let(:base_resource) do
    {
      'resourceType' => 'MedicationRequest',
      'id' => '12345',
      'status' => 'active',
      'authoredOn' => '2025-01-29T19:41:43Z',
      'medicationCodeableConcept' => {
        'text' => 'Test Medication'
      },
      'dosageInstruction' => [
        {
          'text' => 'Take as directed'
        }
      ]
    }
  end

  before do
    allow(Rails.cache).to receive(:exist?).and_return(false)
  end

  describe '#parse' do
    context 'with valid resource' do
      it 'returns a UnifiedHealthData::Prescription object' do
        result = subject.parse(base_resource)

        expect(result).to be_a(UnifiedHealthData::Prescription)
        expect(result.id).to eq('12345')
      end
    end

    context 'with reportedBoolean true' do
      let(:reported_resource) { base_resource.merge('reportedBoolean' => true) }

      it 'returns prescription source NV' do
        result = subject.parse(reported_resource)
        expect(result.prescription_source).to eq('NV') # Should be marked as NV for filtering
      end
    end

    context 'with reportedBoolean false' do
      let(:not_reported_resource) { base_resource.merge('reportedBoolean' => false) }

      it 'returns prescription object for non-reported medications' do
        result = subject.parse(not_reported_resource)
        expect(result.prescription_source).to eq('')
      end
    end

    context 'with nil resource' do
      it 'returns nil' do
        expect(subject.parse(nil)).to be_nil
      end
    end

    context 'with resource missing id' do
      let(:resource_without_id) { base_resource.except('id') }

      it 'returns nil' do
        expect(subject.parse(resource_without_id)).to be_nil
      end
    end

    context 'when parsing raises an error' do
      let(:adapter_with_error) do
        adapter = described_class.new
        allow(adapter).to receive(:extract_refill_date).and_raise(StandardError, 'Test error')
        adapter
      end

      before do
        allow(Rails.logger).to receive(:error)
      end

      it 'logs the error and returns nil' do
        result = adapter_with_error.parse(base_resource)

        expect(result).to be_nil
        expect(Rails.logger).to have_received(:error).with('Error parsing Oracle Health prescription: Test error')
      end
    end
  end

  describe '#extract_prescription_source' do
    context 'with reportedBoolean nil' do
      it 'returns empty string for default VA medications' do
        result = subject.send(:extract_prescription_source, base_resource)
        expect(result).to eq('')
      end
    end
  end

  describe '#extract_facility_name' do
    context 'with MedicationDispense containing station number' do
      let(:resource_with_station_number) do
        base_resource.merge(
          'contained' => [
            {
              'resourceType' => 'MedicationDispense',
              'id' => 'dispense-1',
              'location' => { 'display' => '556-RX-MAIN-OP' }
            }
          ]
        )
      end

      context 'when facility name is cached' do
        before do
          allow(Rails.cache).to receive(:read).with('uhd:facility_names:556').and_return('Cached Facility Name')
          allow(Rails.cache).to receive(:exist?).with('uhd:facility_names:556').and_return(true)
        end

        it 'returns the cached facility name' do
          result = subject.send(:extract_facility_name, resource_with_station_number)
          expect(result).to eq('Cached Facility Name')
        end

        it 'does not call the API when cache hit occurs' do
          # Mock the Lighthouse client to ensure it's not called
          mock_client = instance_double(Lighthouse::Facilities::V1::Client)
          allow(Lighthouse::Facilities::V1::Client).to receive(:new).and_return(mock_client)
          expect(mock_client).not_to receive(:get_facilities)

          subject.send(:extract_facility_name, resource_with_station_number)
        end
      end

      context 'when facility name is not cached' do
        before do
          allow(Rails.cache).to receive(:read).with('uhd:facility_names:556').and_return(nil)
          allow(Rails.cache).to receive(:write)
          allow(Rails.cache).to receive(:exist?).with('uhd:facility_names:556').and_return(false)
        end

        it 'calls the API and returns the facility name' do
          # Mock the Lighthouse API to return a facility
          mock_client = instance_double(Lighthouse::Facilities::V1::Client)
          mock_facility = double('facility', name: 'API Facility Name')
          allow(Lighthouse::Facilities::V1::Client).to receive(:new).and_return(mock_client)
          allow(mock_client).to receive(:get_facilities).with(facilityIds: 'vha_556').and_return([mock_facility])

          result = subject.send(:extract_facility_name, resource_with_station_number)
          expect(result).to eq('API Facility Name')
          expect(mock_client).to have_received(:get_facilities).with(facilityIds: 'vha_556')
        end
      end

      context 'when 3-digit lookup misses but full facility identifier exists' do
        let(:resource_with_extended_station) do
          base_resource.merge(
            'contained' => [
              {
                'resourceType' => 'MedicationDispense',
                'id' => 'dispense-extended',
                'location' => { 'display' => '648A4-RX-MAIN' }
              }
            ]
          )
        end

        before do
          allow(Rails.cache).to receive(:read).with('uhd:facility_names:648').and_return(nil)
          allow(Rails.cache).to receive(:read).with('uhd:facility_names:648A4').and_return('Full Station Facility')
          allow(Rails.cache).to receive(:exist?).with('uhd:facility_names:648').and_return(false)
          allow(Rails.cache).to receive(:exist?).with('uhd:facility_names:648A4').and_return(true)
        end

        it 'falls back to the full station identifier' do
          result = subject.send(:extract_facility_name, resource_with_extended_station)
          expect(result).to eq('Full Station Facility')
        end
      end

      context 'when extended station identifier is invalid' do
        let(:resource_with_invalid_station) do
          base_resource.merge(
            'contained' => [
              {
                'resourceType' => 'MedicationDispense',
                'id' => 'dispense-invalid',
                'location' => { 'display' => 'ABC-RX-MAIN' }
              }
            ]
          )
        end

        it 'returns nil without attempting lookup' do
          expect(subject.send(:extract_facility_name, resource_with_invalid_station)).to be_nil
        end
      end

      context 'when API returns nil' do
        before do
          allow(Rails.cache).to receive(:read).with('uhd:facility_names:556').and_return(nil)
          allow(Rails.cache).to receive(:write)
          allow(Rails.logger).to receive(:warn)
          allow(StatsD).to receive(:increment)
          allow(Rails.cache).to receive(:exist?).with('uhd:facility_names:556').and_return(false)
        end

        it 'returns nil when API call returns nil' do
          # Mock the Lighthouse API to return empty array
          mock_client = instance_double(Lighthouse::Facilities::V1::Client)
          allow(Lighthouse::Facilities::V1::Client).to receive(:new).and_return(mock_client)
          allow(mock_client).to receive(:get_facilities).with(facilityIds: 'vha_556').and_return([])

          result = subject.send(:extract_facility_name, resource_with_station_number)
          expect(result).to be_nil
        end
      end
    end

    context 'with MedicationDispense containing non-standard station format' do
      let(:resource_with_short_station) do
        base_resource.merge(
          'contained' => [
            {
              'resourceType' => 'MedicationDispense',
              'id' => 'dispense-1',
              'location' => { 'display' => '12-PHARMACY' }
            }
          ]
        )
      end

      before do
        allow(Rails.logger).to receive(:error)
      end

      it 'returns nil when station number does not match 3-digit pattern' do
        result = subject.send(:extract_facility_name, resource_with_short_station)
        expect(Rails.logger).to have_received(:error).with(
          'Unable to extract valid station number from: 12-PHARMACY'
        )
        expect(result).to be_nil
      end
    end

    context 'with no MedicationDispense in contained resources' do
      let(:resource_without_dispense) do
        base_resource.merge(
          'contained' => [
            {
              'resourceType' => 'Encounter',
              'id' => 'encounter-1',
              'location' => [
                {
                  'location' => {
                    'display' => 'VA Medical Center - Emergency'
                  }
                }
              ]
            }
          ]
        )
      end

      it 'returns nil when no MedicationDispense found' do
        result = subject.send(:extract_facility_name, resource_without_dispense)
        expect(result).to be_nil
      end
    end

    context 'with MedicationDispense but no location' do
      let(:resource_no_location) do
        base_resource.merge(
          'contained' => [
            {
              'resourceType' => 'MedicationDispense',
              'id' => 'dispense-1'
            },
            {
              'resourceType' => 'Encounter',
              'id' => 'encounter-1',
              'location' => [
                {
                  'location' => {
                    'display' => 'Outpatient Clinic'
                  }
                }
              ]
            },
            {
              'resourceType' => 'Organization',
              'id' => 'org-1'
            }
          ]
        )
      end

      it 'returns nil when MedicationDispense has no location' do
        result = subject.send(:extract_facility_name, resource_no_location)
        expect(result).to be_nil
      end
    end

    context 'with multiple MedicationDispense resources' do
      let(:resource_multiple_dispenses) do
        base_resource.merge(
          'contained' => [
            {
              'resourceType' => 'MedicationDispense',
              'id' => 'dispense-1',
              'location' => { 'display' => '442-RX-MAIN' },
              'whenHandedOver' => '2025-01-15T10:00:00Z'
            },
            {
              'resourceType' => 'MedicationDispense',
              'id' => 'dispense-2',
              'location' => { 'display' => '556-RX-MAIN-OP' },
              'whenHandedOver' => '2025-01-20T10:00:00Z'
            }
          ]
        )
      end

      before do
        allow(Rails.cache).to receive(:read).with('uhd:facility_names:556').and_return('Recent Facility')
        allow(Rails.cache).to receive(:exist?).with('uhd:facility_names:556').and_return(true)
      end

      it 'uses the most recent MedicationDispense for station number' do
        result = subject.send(:extract_facility_name, resource_multiple_dispenses)
        expect(result).to eq('Recent Facility')
      end
    end

    context 'with no contained resources' do
      it 'returns nil when no contained resources exist' do
        result = subject.send(:extract_facility_name, base_resource)
        expect(result).to be_nil
      end
    end
  end

  describe '#fetch_facility_name_from_api' do
    let(:mock_client) { instance_double(Lighthouse::Facilities::V1::Client) }
    let(:mock_facility) { double('facility', name: 'Test VA Medical Center') }

    before do
      allow(Lighthouse::Facilities::V1::Client).to receive(:new).and_return(mock_client)
      allow(Rails.logger).to receive(:info)
      allow(Rails.logger).to receive(:warn)
      allow(StatsD).to receive(:increment)
    end

    context 'when API returns facility data' do
      before do
        allow(mock_client).to receive(:get_facilities).with(facilityIds: 'vha_556').and_return([mock_facility])
        allow(Rails.cache).to receive(:write)
      end

      it 'returns the facility name' do
        result = subject.send(:fetch_facility_name_from_api, '556')
        expect(result).to eq('Test VA Medical Center')
      end

      it 'calls the Lighthouse API with correct facility ID format' do
        subject.send(:fetch_facility_name_from_api, '556')
        expect(mock_client).to have_received(:get_facilities).with(facilityIds: 'vha_556')
      end

      it 'writes the facility name to cache with TTL' do
        subject.send(:fetch_facility_name_from_api, '556')
        expect(Rails.cache).to have_received(:write).with(
          'uhd:facility_names:556',
          'Test VA Medical Center',
          expires_in: 4.hours
        )
      end
    end

    context 'when API returns empty array' do
      before do
        allow(mock_client).to receive(:get_facilities).with(facilityIds: 'vha_556').and_return([])
        allow(Rails.cache).to receive(:write)
      end

      it 'returns nil and logs warning message' do
        result = subject.send(:fetch_facility_name_from_api, '556')
        expect(result).to be_nil
        expect(Rails.logger).to have_received(:warn).with(
          'No facility found for station number 556 in Lighthouse API'
        )
      end

      it 'caches nil result to avoid repeated API calls' do
        subject.send(:fetch_facility_name_from_api, '556')
        expect(Rails.cache).to have_received(:write).with(
          'uhd:facility_names:556',
          nil,
          expires_in: 4.hours
        )
      end
    end

    context 'when API returns nil' do
      before do
        allow(mock_client).to receive(:get_facilities).with(facilityIds: 'vha_556').and_return(nil)
      end

      it 'returns nil and logs warning message' do
        result = subject.send(:fetch_facility_name_from_api, '556')
        expect(result).to be_nil
        expect(Rails.logger).to have_received(:warn).with(
          'No facility found for station number 556 in Lighthouse API'
        )
      end
    end

    context 'when API raises an exception' do
      let(:api_error) { StandardError.new('API connection failed') }

      before do
        allow(mock_client).to receive(:get_facilities).and_raise(api_error)
        allow(Rails.cache).to receive(:write)
        allow(Rails.logger).to receive(:error)
      end

      it 'returns nil, logs error, and increments StatsD metric' do
        result = subject.send(:fetch_facility_name_from_api, '556')

        expect(result).to be_nil
        expect(Rails.logger).to have_received(:error).with(
          'Failed to fetch facility name from API for station 556: API connection failed'
        )
        expect(StatsD).to have_received(:increment).with(
          'unified_health_data.facility_name_fallback.api_error'
        )
      end

      it 'does not cache error results' do
        subject.send(:fetch_facility_name_from_api, '556')
        expect(Rails.cache).not_to have_received(:write)
      end
    end

    context 'when API returns facility without name' do
      let(:facility_without_name) { double('facility', name: nil) }

      before do
        allow(mock_client).to receive(:get_facilities).with(facilityIds: 'vha_556').and_return([facility_without_name])
      end

      it 'returns nil when facility name is nil' do
        result = subject.send(:fetch_facility_name_from_api, '556')
        expect(result).to be_nil
      end
    end

    context 'when API returns multiple facilities' do
      let(:facility_one) { double('facility', name: 'First Facility') }
      let(:facility_two) { double('facility', name: 'Second Facility') }

      before do
        allow(mock_client).to receive(:get_facilities).with(facilityIds: 'vha_556').and_return([facility_one,
                                                                                                facility_two])
      end

      it 'returns the name of the first facility' do
        result = subject.send(:fetch_facility_name_from_api, '556')
        expect(result).to eq('First Facility')
      end
    end
  end

  describe '#extract_is_refillable' do
    let(:base_refillable_resource) do
      {
        'status' => 'active',
        'reportedBoolean' => false,
        'dispenseRequest' => {
          'numberOfRepeatsAllowed' => 5,
          'validityPeriod' => {
            'end' => 1.minute.from_now.in_time_zone('Pacific/Honolulu').iso8601
          }
        },
        'contained' => [
          {
            'resourceType' => 'MedicationDispense',
            'id' => 'dispense-1',
            'status' => 'completed',
            'whenHandedOver' => '2025-01-15T10:00:00Z'
          }
        ]
      }
    end

    context 'with all conditions met for refillable prescription' do
      it 'returns true' do
        expect(subject.send(:extract_is_refillable, base_refillable_resource)).to be true
      end
    end

    context 'with non-VA medication (reportedBoolean true)' do
      let(:non_va_resource) do
        base_refillable_resource.merge('reportedBoolean' => true)
      end

      it 'returns false for non-VA medications' do
        expect(subject.send(:extract_is_refillable, non_va_resource)).to be false
      end
    end

    context 'with inactive status' do
      let(:inactive_resource) do
        base_refillable_resource.merge('status' => 'completed')
      end

      it 'returns false when status is not active' do
        expect(subject.send(:extract_is_refillable, inactive_resource)).to be false
      end
    end

    context 'with null status' do
      let(:null_status_resource) do
        base_refillable_resource.merge('status' => nil)
      end

      it 'returns false when status is null' do
        expect(subject.send(:extract_is_refillable, null_status_resource)).to be false
      end
    end

    context 'with expired prescription' do
      let(:expired_resource) do
        expired_date = 1.minute.ago.in_time_zone('America/Los_Angeles').iso8601
        base_refillable_resource.deep_merge(
          'dispenseRequest' => {
            'validityPeriod' => {
              'end' => expired_date
            }
          }
        )
      end

      it 'returns false when prescription is expired' do
        expect(subject.send(:extract_is_refillable, expired_resource)).to be false
      end
    end

    context 'with no expiration date' do
      let(:no_expiration_resource) do
        resource = base_refillable_resource.dup
        resource['dispenseRequest'].delete('validityPeriod')
        resource
      end

      it 'returns false when no expiration date (safety default)' do
        expect(subject.send(:extract_is_refillable, no_expiration_resource)).to be false
      end
    end

    context 'with invalid expiration date' do
      let(:invalid_expiration_resource) do
        base_refillable_resource.deep_merge(
          'dispenseRequest' => {
            'validityPeriod' => {
              'end' => 'invalid-date'
            }
          }
        )
      end

      before do
        allow(Rails.logger).to receive(:warn)
      end

      it 'returns false and logs warning for invalid dates' do
        expect(subject.send(:extract_is_refillable, invalid_expiration_resource)).to be false
        expect(Rails.logger).to have_received(:warn).with(
          /Invalid expiration date for prescription.*: invalid-date/
        )
      end
    end

    context 'with no refills remaining' do
      let(:no_refills_resource) do
        base_refillable_resource.merge(
          'dispenseRequest' => {
            'numberOfRepeatsAllowed' => 0,
            'validityPeriod' => {
              'end' => 1.year.from_now.iso8601
            }
          }
        )
      end

      it 'returns false when no refills remaining' do
        expect(subject.send(:extract_is_refillable, no_refills_resource)).to be false
      end
    end

    context 'with multiple failing conditions' do
      let(:multiple_fail_resource) do
        {
          'status' => 'completed',
          'reportedBoolean' => true,
          'dispenseRequest' => {
            'numberOfRepeatsAllowed' => 0,
            'validityPeriod' => {
              'end' => 1.day.ago.iso8601
            }
          }
        }
      end

      it 'returns false when multiple conditions fail' do
        expect(subject.send(:extract_is_refillable, multiple_fail_resource)).to be false
      end
    end

    context 'with exactly one refill remaining' do
      let(:one_refill_resource) do
        base_refillable_resource.merge(
          'dispenseRequest' => {
            'numberOfRepeatsAllowed' => 2,
            'validityPeriod' => {
              'end' => 1.year.from_now.iso8601
            }
          },
          'contained' => [
            {
              'resourceType' => 'MedicationDispense',
              'id' => 'dispense-1',
              'status' => 'completed'
            },
            {
              'resourceType' => 'MedicationDispense',
              'id' => 'dispense-2',
              'status' => 'completed'
            }
          ]
        )
      end

      it 'returns true when exactly one refill remains' do
        expect(subject.send(:extract_is_refillable, one_refill_resource)).to be true
      end
    end
  end

  describe '#extract_station_number' do
    let(:resource_with_station_number) do
      {
        'contained' => [
          {
            'resourceType' => 'MedicationDispense',
            'id' => 'dispense-1',
            'location' => { 'display' => '556-RX-MAIN-OP' }
          }
        ]
      }
    end

    context 'with valid 3-digit station number format' do
      it 'extracts the first 3 digits' do
        result = subject.send(:extract_station_number, resource_with_station_number)
        expect(result).to eq('556')
      end
    end

    context 'with format that has less than 3 leading digits' do
      let(:resource_with_short_digits) do
        {
          'contained' => [
            {
              'resourceType' => 'MedicationDispense',
              'id' => 'dispense-1',
              'location' => { 'display' => '12-PHARMACY' }
            }
          ]
        }
      end

      before do
        allow(Rails.logger).to receive(:warn)
      end

      it 'falls back to original value and logs warning' do
        result = subject.send(:extract_station_number, resource_with_short_digits)
        expect(result).to eq('12-PHARMACY')
        expect(Rails.logger).to have_received(:warn).with(
          'Unable to extract 3-digit station number from: 12-PHARMACY'
        )
      end
    end

    context 'with no MedicationDispense in contained resources' do
      let(:resource_without_dispense) do
        {
          'contained' => [
            {
              'resourceType' => 'Encounter',
              'id' => 'encounter-1'
            }
          ]
        }
      end

      it 'returns nil' do
        result = subject.send(:extract_station_number, resource_without_dispense)
        expect(result).to be_nil
      end
    end
  end

  describe '#extract_refill_remaining' do
    context 'with non-VA medication' do
      let(:non_va_resource) do
        {
          'reportedBoolean' => true,
          'dispenseRequest' => {
            'numberOfRepeatsAllowed' => 5
          }
        }
      end

      it 'returns 0 for non-VA medications' do
        result = subject.send(:extract_refill_remaining, non_va_resource)
        expect(result).to eq(0)
      end
    end

    context 'with VA medication and no completed dispenses' do
      let(:resource_no_dispenses) do
        {
          'reportedBoolean' => false,
          'dispenseRequest' => {
            'numberOfRepeatsAllowed' => 5
          }
        }
      end

      it 'returns the full number of repeats allowed' do
        result = subject.send(:extract_refill_remaining, resource_no_dispenses)
        expect(result).to eq(5)
      end
    end

    context 'with VA medication and one completed dispense (initial fill)' do
      let(:resource_one_dispense) do
        {
          'reportedBoolean' => false,
          'dispenseRequest' => {
            'numberOfRepeatsAllowed' => 5
          },
          'contained' => [
            {
              'resourceType' => 'MedicationDispense',
              'id' => 'dispense-1',
              'status' => 'completed'
            }
          ]
        }
      end

      it 'returns the full number of repeats (initial fill does not count against refills)' do
        result = subject.send(:extract_refill_remaining, resource_one_dispense)
        expect(result).to eq(5)
      end
    end

    context 'with VA medication and multiple completed dispenses' do
      let(:resource_multiple_dispenses) do
        {
          'reportedBoolean' => false,
          'dispenseRequest' => {
            'numberOfRepeatsAllowed' => 5
          },
          'contained' => [
            {
              'resourceType' => 'MedicationDispense',
              'id' => 'dispense-1',
              'status' => 'completed'
            },
            {
              'resourceType' => 'MedicationDispense',
              'id' => 'dispense-2',
              'status' => 'completed'
            },
            {
              'resourceType' => 'MedicationDispense',
              'id' => 'dispense-3',
              'status' => 'completed'
            }
          ]
        }
      end

      it 'subtracts refills used (excluding initial fill)' do
        # 3 completed dispenses = 1 initial + 2 refills used
        # 5 allowed - 2 used = 3 remaining
        result = subject.send(:extract_refill_remaining, resource_multiple_dispenses)
        expect(result).to eq(3)
      end
    end

    context 'with VA medication and all refills used' do
      let(:resource_all_refills_used) do
        {
          'reportedBoolean' => false,
          'dispenseRequest' => {
            'numberOfRepeatsAllowed' => 2
          },
          'contained' => [
            {
              'resourceType' => 'MedicationDispense',
              'id' => 'dispense-1',
              'status' => 'completed'
            },
            {
              'resourceType' => 'MedicationDispense',
              'id' => 'dispense-2',
              'status' => 'completed'
            },
            {
              'resourceType' => 'MedicationDispense',
              'id' => 'dispense-3',
              'status' => 'completed'
            }
          ]
        }
      end

      it 'returns 0 when all refills are used' do
        # 3 completed dispenses = 1 initial + 2 refills used
        # 2 allowed - 2 used = 0 remaining
        result = subject.send(:extract_refill_remaining, resource_all_refills_used)
        expect(result).to eq(0)
      end
    end

    context 'with VA medication and over-dispensed (more dispenses than allowed)' do
      let(:resource_over_dispensed) do
        {
          'reportedBoolean' => false,
          'dispenseRequest' => {
            'numberOfRepeatsAllowed' => 1
          },
          'contained' => [
            {
              'resourceType' => 'MedicationDispense',
              'id' => 'dispense-1',
              'status' => 'completed'
            },
            {
              'resourceType' => 'MedicationDispense',
              'id' => 'dispense-2',
              'status' => 'completed'
            },
            {
              'resourceType' => 'MedicationDispense',
              'id' => 'dispense-3',
              'status' => 'completed'
            }
          ]
        }
      end

      it 'returns 0 when more dispenses than allowed' do
        # 3 completed dispenses = 1 initial + 2 refills used
        # 1 allowed - 2 used = -1, but should return 0
        result = subject.send(:extract_refill_remaining, resource_over_dispensed)
        expect(result).to eq(0)
      end
    end

    context 'with mixed dispense statuses' do
      let(:resource_mixed_statuses) do
        {
          'reportedBoolean' => false,
          'dispenseRequest' => {
            'numberOfRepeatsAllowed' => 5
          },
          'contained' => [
            {
              'resourceType' => 'MedicationDispense',
              'id' => 'dispense-1',
              'status' => 'completed'
            },
            {
              'resourceType' => 'MedicationDispense',
              'id' => 'dispense-2',
              'status' => 'in-progress'
            },
            {
              'resourceType' => 'MedicationDispense',
              'id' => 'dispense-3',
              'status' => 'completed'
            }
          ]
        }
      end

      it 'only counts completed dispenses' do
        # 2 completed dispenses = 1 initial + 1 refill used
        # 5 allowed - 1 used = 4 remaining
        result = subject.send(:extract_refill_remaining, resource_mixed_statuses)
        expect(result).to eq(4)
      end
    end

    context 'with no numberOfRepeatsAllowed specified' do
      let(:resource_no_repeats) do
        {
          'reportedBoolean' => false,
          'dispenseRequest' => {}
        }
      end

      it 'defaults to 0 repeats allowed' do
        result = subject.send(:extract_refill_remaining, resource_no_repeats)
        expect(result).to eq(0)
      end
    end

    context 'with no dispenseRequest' do
      let(:resource_no_dispense_request) do
        {
          'reportedBoolean' => false
        }
      end

      it 'defaults to 0 repeats allowed' do
        result = subject.send(:extract_refill_remaining, resource_no_dispense_request)
        expect(result).to eq(0)
      end
    end

    context 'with no contained resources' do
      let(:resource_no_contained) do
        {
          'reportedBoolean' => false,
          'dispenseRequest' => {
            'numberOfRepeatsAllowed' => 3
          }
        }
      end

      it 'returns the full number of repeats allowed' do
        result = subject.send(:extract_refill_remaining, resource_no_contained)
        expect(result).to eq(3)
      end
    end

    context 'with non-MedicationDispense resources in contained' do
      let(:resource_no_med_dispenses) do
        {
          'reportedBoolean' => false,
          'dispenseRequest' => {
            'numberOfRepeatsAllowed' => 4
          },
          'contained' => [
            {
              'resourceType' => 'Encounter',
              'id' => 'encounter-1'
            },
            {
              'resourceType' => 'Organization',
              'id' => 'org-1'
            }
          ]
        }
      end

      it 'returns the full number of repeats allowed when no MedicationDispense resources' do
        result = subject.send(:extract_refill_remaining, resource_no_med_dispenses)
        expect(result).to eq(4)
      end
    end
  end

  describe '#build_tracking_information' do
    context 'with MedicationDispense containing tracking identifiers' do
      let(:resource_with_tracking) do
        base_resource.merge(
          'contained' => [
            {
              'resourceType' => 'MedicationDispense',
              'id' => '21142623',
              'identifier' => [
                {
                  'type' => { 'text' => 'Tracking Number' },
                  'value' => '77298027203980000000398'
                },
                {
                  'type' => { 'text' => 'Prescription Number' },
                  'value' => '2720334'
                },
                {
                  'type' => { 'text' => 'Carrier' },
                  'value' => 'UPS'
                },
                {
                  'type' => { 'text' => 'Shipped Date' },
                  'value' => '2022-10-15T00:00:00.000Z'
                }
              ],
              'medicationCodeableConcept' => {
                'coding' => [
                  {
                    'system' => 'http://hl7.org/fhir/sid/ndc',
                    'code' => '00013264681'
                  }
                ]
              }
            }
          ],
          'medicationCodeableConcept' => {
            'text' => 'HALCINONIDE 0.1% OINT'
          }
        )
      end

      it 'returns tracking information with all fields' do
        result = subject.send(:build_tracking_information, resource_with_tracking)

        expect(result).to be_an(Array)
        expect(result.length).to eq(1)

        tracking = result.first
        expect(tracking).to include(
          prescription_name: 'HALCINONIDE 0.1% OINT',
          prescription_number: '2720334',
          ndc_number: '00013264681',
          prescription_id: '12345',
          tracking_number: '77298027203980000000398',
          shipped_date: '2022-10-15T00:00:00.000Z',
          carrier: 'UPS',
          other_prescriptions: []
        )
      end

      it 'sets is_trackable to true when tracking data exists' do
        result = subject.parse(resource_with_tracking)
        expect(result.is_trackable).to be(true)
      end
    end

    context 'with MedicationDispense without tracking identifiers' do
      let(:resource_no_tracking) do
        base_resource.merge(
          'contained' => [
            {
              'resourceType' => 'MedicationDispense',
              'id' => '123456',
              'identifier' => [
                {
                  'type' => { 'text' => 'Other ID' },
                  'value' => 'some-other-value'
                }
              ]
            }
          ]
        )
      end

      it 'returns empty array when no tracking number is found' do
        result = subject.send(:build_tracking_information, resource_no_tracking)
        expect(result).to eq([])
      end

      it 'sets is_trackable to false when no tracking data exists' do
        result = subject.parse(resource_no_tracking)
        expect(result.is_trackable).to be(false)
      end
    end

    context 'with multiple MedicationDispense resources' do
      let(:resource_multiple_dispenses) do
        base_resource.merge(
          'contained' => [
            {
              'resourceType' => 'MedicationDispense',
              'id' => '111',
              'identifier' => [
                {
                  'type' => { 'text' => 'Tracking Number' },
                  'value' => 'TRACK111'
                },
                {
                  'type' => { 'text' => 'Carrier' },
                  'value' => 'USPS'
                }
              ]
            },
            {
              'resourceType' => 'MedicationDispense',
              'id' => '222',
              'identifier' => [
                {
                  'type' => { 'text' => 'Tracking Number' },
                  'value' => 'TRACK222'
                },
                {
                  'type' => { 'text' => 'Carrier' },
                  'value' => 'FedEx'
                }
              ]
            }
          ]
        )
      end

      it 'returns tracking information for all dispenses with tracking numbers' do
        result = subject.send(:build_tracking_information, resource_multiple_dispenses)

        expect(result).to be_an(Array)
        expect(result.length).to eq(2)

        expect(result.map { |t| t[:tracking_number] }).to contain_exactly('TRACK111', 'TRACK222')
        expect(result.map { |t| t[:carrier] }).to contain_exactly('USPS', 'FedEx')
      end
    end

    context 'with no contained resources' do
      it 'returns empty array' do
        result = subject.send(:build_tracking_information, base_resource)
        expect(result).to eq([])
      end

      it 'sets is_trackable to false' do
        result = subject.parse(base_resource)
        expect(result.is_trackable).to be(false)
      end
    end
  end

  describe '#extract_ndc_number' do
    context 'with NDC coding in medicationCodeableConcept' do
      let(:dispense_with_ndc) do
        {
          'resourceType' => 'MedicationDispense',
          'id' => 'dispense-1',
          'medicationCodeableConcept' => {
            'coding' => [
              {
                'system' => 'http://hl7.org/fhir/sid/ndc',
                'code' => '12345-678-90'
              },
              {
                'system' => 'http://other.system',
                'code' => 'OTHER123'
              }
            ]
          }
        }
      end

      it 'returns the NDC code' do
        result = subject.send(:extract_ndc_number, dispense_with_ndc)
        expect(result).to eq('12345-678-90')
      end
    end

    context 'without NDC coding' do
      let(:dispense_without_ndc) do
        {
          'resourceType' => 'MedicationDispense',
          'id' => 'dispense-1'
        }
      end

      it 'returns nil' do
        result = subject.send(:extract_ndc_number, dispense_without_ndc)
        expect(result).to be_nil
      end
    end
  end
end
