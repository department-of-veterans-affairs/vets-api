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
    context 'with dispenseRequest performer' do
      let(:resource_with_performer) do
        base_resource.merge(
          'dispenseRequest' => {
            'performer' => {
              'display' => 'Main Pharmacy'
            }
          }
        )
      end

      it 'returns the performer display name' do
        result = subject.send(:extract_facility_name, resource_with_performer)
        expect(result).to eq('Main Pharmacy')
      end
    end

    context 'with encounter location in contained resources' do
      let(:resource_with_encounter) do
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

      it 'returns the encounter location display name' do
        result = subject.send(:extract_facility_name, resource_with_encounter)
        expect(result).to eq('VA Medical Center - Emergency')
      end
    end

    context 'with multiple contained resources including encounter' do
      let(:resource_with_multiple_contained) do
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

      it 'finds and returns the encounter location display name' do
        result = subject.send(:extract_facility_name, resource_with_multiple_contained)
        expect(result).to eq('Outpatient Clinic')
      end
    end

    context 'with encounter but no location' do
      let(:resource_with_encounter_no_location) do
        base_resource.merge(
          'contained' => [
            {
              'resourceType' => 'Encounter',
              'id' => 'encounter-1'
            }
          ],
          'requester' => {
            'display' => 'Fallback Provider'
          }
        )
      end
    end

    context 'with no performer, encounter, or requester' do
      it 'returns nil' do
        result = subject.send(:extract_facility_name, base_resource)
        expect(result).to be_nil
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
