# frozen_string_literal: true

require 'rails_helper'
require 'unified_health_data/models/prescription'
require 'unified_health_data/adapters/prescriptions_adapter'

describe UnifiedHealthData::Adapters::PrescriptionsAdapter do
  subject { described_class.new(user) }

  let(:user) { build(:user, :loa3, icn: '1000123456V123456') }
  let(:vista_medication_data) do
    {
      'prescriptionId' => '28148665',
      'refillStatus' => 'active',
      'refillSubmitDate' => nil,
      'refillDate' => 'Mon, 14 Jul 2025 00:00:00 EDT',
      'refillRemaining' => 11,
      'facilityName' => 'SLC4',
      'isRefillable' => true,
      'isTrackable' => false,
      'sig' => 'APPLY TEASPOONFUL(S) TO THE AFFECTED AREA EVERY DAY',
      'orderedDate' => 'Mon, 14 Jul 2025 00:00:00 EDT',
      'quantity' => 1,
      'expirationDate' => 'Wed, 15 Jul 2026 00:00:00 EDT',
      'prescriptionNumber' => '3636485',
      'prescriptionName' => 'COAL TAR 2.5% TOP SOLN',
      'dispensedDate' => nil,
      'stationNumber' => '991',
      'cmopDivisionPhone' => '555-1234',
      'providerLastName' => 'SMITH',
      'providerFirstName' => 'JOHN',
      'dialCmopDivisionPhone' => '555-DIAL',
      'remarks' => 'TEST REMARKS FOR VISTA',
      'cmopNdcNumber' => '00093721410',
      'dataSourceSystem' => 'VISTA'
    }
  end
  let(:oracle_health_medication_data) do
    {
      'resourceType' => 'MedicationRequest',
      'id' => '15208365735',
      'status' => 'active',
      'authoredOn' => '2025-01-29T19:41:43Z',
      'reportedBoolean' => false,
      'intent' => 'order',
      'category' => [
        {
          'coding' => [
            { 'system' => 'http://terminology.hl7.org/CodeSystem/medicationrequest-admin-location', 'code' => 'community' }
          ]
        },
        {
          'coding' => [
            { 'system' => 'http://terminology.hl7.org/CodeSystem/medication-request-category', 'code' => 'discharge' }
          ]
        }
      ],
      'requester' => {
        'reference' => 'Practitioner/12345',
        'display' => 'Doe, Jane, MD'
      },
      'medicationCodeableConcept' => {
        'text' => 'amLODIPine (amLODIPine 5 mg tablet)'
      },
      'dosageInstruction' => [
        {
          'text' => 'See Instructions, daily, 1 EA, 0 Refill(s)'
        }
      ],
      'dispenseRequest' => {
        'numberOfRepeatsAllowed' => 0,
        'quantity' => {
          'value' => 1,
          'unit' => 'EA'
        }
      },
      'note' => [
        { 'text' => 'Take with food.' },
        { 'text' => 'May cause dizziness.' }
      ],
      'contained' => [
        {
          'resourceType' => 'MedicationDispense',
          'id' => 'dispense-1',
          'whenHandedOver' => '2025-01-15T10:00:00Z',
          'quantity' => { 'value' => 30 },
          'location' => { 'display' => 'Main Pharmacy' }
        },
        {
          'resourceType' => 'MedicationDispense',
          'id' => 'dispense-2',
          'whenHandedOver' => '2025-01-29T14:30:00Z',
          'quantity' => { 'value' => 30 },
          'location' => { 'display' => 'Main Pharmacy' }
        },
        {
          'resourceType' => 'MedicationDispense',
          'id' => 'dispense-3',
          'whenHandedOver' => '2025-01-22T09:15:00Z',
          'quantity' => { 'value' => 30 },
          'location' => { 'display' => 'Main Pharmacy' }
        }
      ]
    }
  end
  let(:unified_response) do
    {
      'vista' => {
        'medicationList' => {
          'medication' => [vista_medication_data]
        }
      },
      'oracle-health' => {
        'entry' => [
          {
            'resource' => oracle_health_medication_data
          }
        ]
      }
    }
  end

  before do
    allow(Rails.cache).to receive(:exist?).and_return(false)
  end

  describe '#parse' do
    context 'with unified response data' do
      before do
        # Ensure business rules filtering doesn't interfere with basic parsing tests
        allow(Flipper).to receive(:enabled?).with(:mhv_medications_display_pending_meds, user).and_return(false)
      end

      it 'returns prescriptions from both VistA and Oracle Health' do
        prescriptions = subject.parse(unified_response)

        expect(prescriptions.size).to eq(2)
        expect(prescriptions).to all(be_a(UnifiedHealthData::Prescription))

        vista_prescription = prescriptions.find { |p| p.prescription_id == '28148665' }
        oracle_prescription = prescriptions.find { |p| p.prescription_id == '15208365735' }

        expect(vista_prescription).to be_present
        expect(oracle_prescription).to be_present
      end

      it 'extracts provider_name from VistA data' do
        prescriptions = subject.parse(unified_response)
        vista_prescription = prescriptions.find { |p| p.prescription_id == '28148665' }

        expect(vista_prescription.provider_name).to eq('SMITH, JOHN')
      end

      it 'extracts provider_name from Oracle Health data' do
        prescriptions = subject.parse(unified_response)
        oracle_prescription = prescriptions.find { |p| p.prescription_id == '15208365735' }

        expect(oracle_prescription.provider_name).to eq('Doe, Jane, MD')
      end

      it 'sets cmop_division_phone correctly for both sources' do
        prescriptions = subject.parse(unified_response)

        vista_prescription = prescriptions.find { |p| p.prescription_id == '28148665' }
        oracle_prescription = prescriptions.find { |p| p.prescription_id == '15208365735' }

        expect(vista_prescription.cmop_division_phone).to eq('555-1234')
        expect(oracle_prescription.cmop_division_phone).to be_nil
      end

      it 'sets cmop_ndc_number from VistA source and null for Oracle Health source' do
        prescriptions = subject.parse(unified_response)

        vista_prescription = prescriptions.find { |p| p.prescription_id == '28148665' }
        oracle_prescription = prescriptions.find { |p| p.prescription_id == '15208365735' }

        expect(vista_prescription.cmop_ndc_number).to eq('00093721410')
        expect(oracle_prescription.cmop_ndc_number).to be_nil
      end

      it 'extracts disp_status from VistA data when present' do
        # When V2 status mapping flag is disabled, disp_status should be preserved as-is from VistA
        allow(Flipper).to receive(:enabled?).with(:mhv_medications_v2_status_mapping, anything).and_return(false)

        vista_data_with_disp_status = vista_medication_data.merge('dispStatus' => 'Active: Refill in Process')
        response_with_disp_status = {
          'vista' => { 'medicationList' => { 'medication' => [vista_data_with_disp_status] } },
          'oracle-health' => { 'entry' => [] }
        }

        prescriptions = subject.parse(response_with_disp_status)
        vista_prescription = prescriptions.first

        expect(vista_prescription.disp_status).to eq('Active: Refill in Process')
      end

      it 'sets disp_status derived from refill_status for Oracle Health prescriptions' do
        # When V2 status mapping flag is disabled, disp_status is derived from refill_status
        # only when dispStatus is not already set, and not mapped to V2 format
        allow(Flipper).to receive(:enabled?).with(:mhv_medications_v2_status_mapping, anything).and_return(false)

        prescriptions = subject.parse(unified_response)
        oracle_prescription = prescriptions.find { |p| p.prescription_id == '15208365735' }

        # Oracle Health prescription with status='active', 0 refills remaining, no expiration date
        # = 'active' refill_status which maps to 'Active' disp_status
        # (derived from refill_status when dispStatus is null)
        expect(oracle_prescription.disp_status).to eq('Active')
      end

      context 'business rules filtering (applied regardless of current_only)' do
        context 'when display_pending_meds flipper is enabled' do
          let(:vista_medication_pf) do
            vista_medication_data.merge('prescriptionSource' => 'PF')
          end

          let(:vista_medication_pd) do
            vista_medication_data.merge('prescriptionSource' => 'PD')
          end

          let(:response_with_pf) do
            {
              'vista' => { 'medicationList' => { 'medication' => [vista_medication_pf] } },
              'oracle-health' => { 'entry' => [] }
            }
          end

          let(:response_with_pd) do
            {
              'vista' => { 'medicationList' => { 'medication' => [vista_medication_pd] } },
              'oracle-health' => { 'entry' => [] }
            }
          end

          before do
            allow(Flipper).to receive(:enabled?).with(:mhv_medications_display_pending_meds, user).and_return(true)
          end

          it 'excludes PF (Partial Fill) prescriptions only' do
            prescriptions = subject.parse(response_with_pf)
            expect(prescriptions).to be_empty
          end

          it 'includes PD (Pending) prescriptions when flag is enabled' do
            prescriptions = subject.parse(response_with_pd)
            expect(prescriptions.size).to eq(1)
            expect(prescriptions.first.prescription_source).to eq('PD')
          end
        end

        context 'when display_pending_meds flipper is disabled' do
          let(:vista_medication_pf) do
            vista_medication_data.merge('prescriptionSource' => 'PF')
          end

          let(:vista_medication_pd) do
            vista_medication_data.merge('prescriptionSource' => 'PD')
          end

          let(:response_with_pf_and_pd) do
            {
              'vista' => { 'medicationList' => { 'medication' => [vista_medication_pf, vista_medication_pd] } },
              'oracle-health' => { 'entry' => [] }
            }
          end

          before do
            allow(Flipper).to receive(:enabled?).with(:mhv_medications_display_pending_meds, user).and_return(false)
          end

          it 'excludes both PF and PD prescriptions' do
            prescriptions = subject.parse(response_with_pf_and_pd)
            expect(prescriptions).to be_empty
          end
        end
      end

      context 'with current_only: false (default)' do
        it 'returns all prescriptions without filtering' do
          prescriptions = subject.parse(unified_response, current_only: false)

          expect(prescriptions.size).to eq(2)
          expect(prescriptions).to all(be_a(UnifiedHealthData::Prescription))
        end
      end

      context 'with current_only: true' do
        let(:vista_medication_expired_old) do
          vista_medication_data.merge(
            'refillStatus' => 'expired',
            'expirationDate' => 200.days.ago.strftime('%a, %d %b %Y %H:%M:%S %Z')
          )
        end

        context 'filters out old discontinued/expired prescriptions' do
          let(:response_with_old_expired) do
            {
              'vista' => { 'medicationList' => { 'medication' => [vista_medication_expired_old] } },
              'oracle-health' => { 'entry' => [] }
            }
          end

          it 'excludes expired prescriptions older than 180 days' do
            allow(Rails.logger).to receive(:info)

            prescriptions = subject.parse(response_with_old_expired, current_only: true)

            expect(prescriptions).to be_empty
            expect(Rails.logger).to have_received(:info).with(
              hash_including(
                message: 'Applied current filtering to prescriptions',
                excluded_count: 1
              )
            )
          end
        end

        context 'handles invalid expiration dates gracefully' do
          let(:vista_medication_invalid_date) do
            vista_medication_data.merge(
              'refillStatus' => 'expired',
              'expirationDate' => 'invalid-date'
            )
          end

          let(:response_with_invalid_date) do
            {
              'vista' => { 'medicationList' => { 'medication' => [vista_medication_invalid_date] } },
              'oracle-health' => { 'entry' => [] }
            }
          end

          it 'logs warning and does not exclude based on date' do
            allow(Rails.logger).to receive(:warn)
            allow(Rails.logger).to receive(:info)

            prescriptions = subject.parse(response_with_invalid_date, current_only: true)

            expect(prescriptions.size).to eq(1)
            expect(Rails.logger).to have_received(:warn).with(
              /Invalid expiration date for rx ending in \d{4}: invalid-date/
            )
          end
        end

        context 'does not filter active or recent prescriptions' do
          it 'includes active prescriptions regardless of expiration date' do
            allow(Rails.logger).to receive(:info)

            prescriptions = subject.parse(unified_response, current_only: true)

            expect(prescriptions.size).to eq(2)
            expect(Rails.logger).to have_received(:info).with(
              hash_including(
                message: 'Applied current filtering to prescriptions',
                original_count: 2,
                filtered_count: 2,
                excluded_count: 0
              )
            )
          end
        end
      end
    end

    context 'with VistA-only data' do
      let(:vista_only_response) do
        {
          'vista' => unified_response['vista'],
          'oracle-health' => nil
        }
      end

      it 'returns only VistA prescriptions' do
        prescriptions = subject.parse(vista_only_response)

        expect(prescriptions.size).to eq(1)
        expect(prescriptions.first.prescription_id).to eq('28148665')
        expect(prescriptions.first.prescription_name).to eq('COAL TAR 2.5% TOP SOLN')
      end

      it 'falls back to orderableItem when prescriptionName is missing' do
        vista_data_without_name = vista_medication_data.merge(
          'prescriptionName' => nil,
          'orderableItem' => 'METFORMIN 500MG TABLET'
        )
        response = {
          'vista' => { 'medicationList' => { 'medication' => [vista_data_without_name] } },
          'oracle-health' => nil
        }

        prescriptions = subject.parse(response)

        expect(prescriptions.size).to eq(1)
        expect(prescriptions.first.prescription_name).to eq('METFORMIN 500MG TABLET')
      end
    end

    context 'with Oracle Health-only data' do
      let(:oracle_only_response) do
        {
          'vista' => nil,
          'oracle-health' => unified_response['oracle-health']
        }
      end

      it 'returns only Oracle Health prescriptions' do
        prescriptions = subject.parse(oracle_only_response)

        expect(prescriptions.size).to eq(1)
        expect(prescriptions.first.prescription_id).to eq('15208365735')
        expect(prescriptions.first.prescription_name).to eq('amLODIPine (amLODIPine 5 mg tablet)')
      end
    end

    context 'with nil input' do
      it 'returns empty array' do
        expect(subject.parse(nil)).to eq([])
      end
    end

    context 'with empty data' do
      let(:empty_response) do
        {
          'vista' => { 'medicationList' => { 'medication' => [] } },
          'oracle-health' => { 'entry' => [] }
        }
      end

      it 'returns empty array' do
        expect(subject.parse(empty_response)).to eq([])
      end
    end

    context 'with Oracle Health data containing multiple MedicationDispense resources' do
      it 'uses the most recent dispensed date based on whenHandedOver' do
        prescriptions = subject.parse(unified_response)
        oracle_prescription = prescriptions.find { |p| p.prescription_id == '15208365735' }

        # Should use the most recent whenHandedOver date: '2025-01-29T14:30:00Z'
        expect(oracle_prescription.refill_date).to eq('2025-01-29T14:30:00Z')
      end
    end

    context 'with Oracle Health data containing dispense location' do
      let(:oracle_medication_with_dispense) do
        {
          'resourceType' => 'MedicationRequest',
          'id' => '15208365735',
          'status' => 'active',
          'authoredOn' => '2025-01-29T19:41:43Z',
          'medicationCodeableConcept' => {
            'text' => 'amLODIPine (amLODIPine 5 mg tablet)'
          },
          'contained' => [
            {
              'resourceType' => 'MedicationDispense',
              'id' => 'dispense-1',
              'status' => 'completed',
              'whenHandedOver' => '2025-01-29T14:30:00Z',
              'location' => {
                'display' => '648-PHARMACY-MAIN'
              }
            }
          ]
        }
      end

      let(:response_with_dispense) do
        {
          'vista' => nil,
          'oracle-health' => {
            'entry' => [
              {
                'resource' => oracle_medication_with_dispense
              }
            ]
          }
        }
      end

      before do
        # Mock Rails cache to return a facility name for station 648
        allow(Rails.cache).to receive(:read).with('uhd:facility_names:648').and_return('Portland VA Medical Center')
        allow(Rails.cache).to receive(:exist?).with('uhd:facility_names:648').and_return(true)
        allow(StatsD).to receive(:increment)
      end

      it 'extracts facility name from dispense location via cache' do
        prescriptions = subject.parse(response_with_dispense)
        oracle_prescription = prescriptions.first

        expect(oracle_prescription.facility_name).to eq('Portland VA Medical Center')
      end
    end

    context 'with Oracle Health inpatient prescriptions' do
      let(:oracle_medication_inpatient) do
        oracle_health_medication_data.merge(
          'category' => [
            {
              'coding' => [
                {
                  'system' => 'http://terminology.hl7.org/CodeSystem/medicationrequest-admin-location',
                  'code' => 'inpatient'
                }
              ]
            }
          ]
        )
      end

      let(:response_with_inpatient) do
        {
          'vista' => nil,
          'oracle-health' => {
            'entry' => [
              {
                'resource' => oracle_medication_inpatient
              }
            ]
          }
        }
      end

      it 'excludes inpatient prescriptions' do
        prescriptions = subject.parse(response_with_inpatient)
        expect(prescriptions).to be_empty
      end
    end

    context 'with Oracle Health outpatient prescriptions' do
      let(:oracle_medication_outpatient) do
        oracle_health_medication_data.merge(
          'category' => [
            {
              'coding' => [
                {
                  'system' => 'http://terminology.hl7.org/CodeSystem/medicationrequest-admin-location',
                  'code' => 'outpatient'
                }
              ]
            }
          ]
        )
      end

      let(:response_with_outpatient) do
        {
          'vista' => nil,
          'oracle-health' => {
            'entry' => [
              {
                'resource' => oracle_medication_outpatient
              }
            ]
          }
        }
      end

      it 'includes outpatient prescriptions' do
        prescriptions = subject.parse(response_with_outpatient)
        expect(prescriptions.size).to eq(1)
        expect(prescriptions.first.category).to eq(['outpatient'])
      end
    end

    context 'with Oracle Health community prescriptions' do
      let(:oracle_medication_community) do
        oracle_health_medication_data.merge(
          'category' => [
            {
              'coding' => [
                {
                  'system' => 'http://terminology.hl7.org/CodeSystem/medicationrequest-admin-location',
                  'code' => 'community'
                }
              ]
            }
          ]
        )
      end

      let(:response_with_community) do
        {
          'vista' => nil,
          'oracle-health' => {
            'entry' => [
              {
                'resource' => oracle_medication_community
              }
            ]
          }
        }
      end

      it 'includes community prescriptions' do
        prescriptions = subject.parse(response_with_community)
        expect(prescriptions.size).to eq(1)
        expect(prescriptions.first.category).to eq(['community'])
      end
    end

    context 'with Oracle Health prescriptions with multiple categories' do
      let(:oracle_medication_multiple_categories) do
        oracle_health_medication_data.merge(
          'category' => [
            {
              'coding' => [
                {
                  'system' => 'http://terminology.hl7.org/CodeSystem/medicationrequest-admin-location',
                  'code' => 'outpatient'
                }
              ]
            },
            {
              'coding' => [
                {
                  'system' => 'http://terminology.hl7.org/CodeSystem/medicationrequest-admin-location',
                  'code' => 'community'
                }
              ]
            }
          ]
        )
      end

      let(:response_with_multiple_categories) do
        {
          'vista' => nil,
          'oracle-health' => {
            'entry' => [
              {
                'resource' => oracle_medication_multiple_categories
              }
            ]
          }
        }
      end

      it 'includes prescriptions with multiple categories' do
        prescriptions = subject.parse(response_with_multiple_categories)
        expect(prescriptions.size).to eq(1)
        expect(prescriptions.first.category).to eq(%w[community outpatient])
      end
    end

    context 'with Oracle Health prescriptions with inpatient in multiple categories' do
      let(:oracle_medication_inpatient_and_community) do
        oracle_health_medication_data.merge(
          'category' => [
            {
              'coding' => [
                {
                  'system' => 'http://terminology.hl7.org/CodeSystem/medicationrequest-admin-location',
                  'code' => 'inpatient'
                }
              ]
            },
            {
              'coding' => [
                {
                  'system' => 'http://terminology.hl7.org/CodeSystem/medicationrequest-admin-location',
                  'code' => 'community'
                }
              ]
            }
          ]
        )
      end

      let(:response_with_inpatient_and_community) do
        {
          'vista' => nil,
          'oracle-health' => {
            'entry' => [
              {
                'resource' => oracle_medication_inpatient_and_community
              }
            ]
          }
        }
      end

      it 'excludes prescriptions if any category is inpatient' do
        prescriptions = subject.parse(response_with_inpatient_and_community)
        expect(prescriptions).to be_empty
      end
    end

    context 'with Vista prescriptions containing dispenses' do
      let(:vista_medication_with_dispenses) do
        vista_medication_data.merge(
          'rxRFRecords' => {
            'rfRecord' => [
              {
                'id' => 'rf-1',
                'refillStatus' => 'dispensed',
                'refillDate' => 'Mon, 14 Jul 2025 00:00:00 EDT',
                'refillSubmitDate' => 'Sun, 13 Jul 2025 00:00:00 EDT',
                'facilityName' => 'SLC4',
                'sig' => 'APPLY TEASPOONFUL(S) TO THE AFFECTED AREA EVERY DAY',
                'quantity' => 1,
                'prescriptionName' => 'COAL TAR 2.5% TOP SOLN',
                'prescriptionNumber' => 'RX001',
                'cmopDivisionPhone' => '800-555-0100',
                'cmopNdcNumber' => '12345-678-90',
                'remarks' => 'Handle with care',
                'dialCmopDivisionPhone' => '8005550100',
                'disclaimer' => 'This is a test disclaimer'
              },
              {
                'id' => 'rf-2',
                'refillStatus' => 'dispensed',
                'refillDate' => 'Tue, 15 Jul 2025 00:00:00 EDT',
                'facilityName' => 'SLC4',
                'sig' => 'APPLY TEASPOONFUL(S) TO THE AFFECTED AREA EVERY DAY',
                'quantity' => 1,
                'prescriptionName' => 'COAL TAR 2.5% TOP SOLN'
              }
            ]
          }
        )
      end

      let(:response_with_vista_dispenses) do
        {
          'vista' => {
            'medicationList' => {
              'medication' => [vista_medication_with_dispenses]
            }
          },
          'oracle-health' => nil
        }
      end

      it 'includes dispenses in Vista prescriptions' do
        prescriptions = subject.parse(response_with_vista_dispenses)

        expect(prescriptions.size).to eq(1)
        vista_prescription = prescriptions.first

        expect(vista_prescription.dispenses).to be_an(Array)
        expect(vista_prescription.dispenses.size).to eq(2)

        first_dispense = vista_prescription.dispenses.first
        expect(first_dispense[:status]).to eq('dispensed')
        expect(first_dispense[:refill_date]).to eq('2025-07-14T04:00:00.000Z')
        expect(first_dispense[:refill_submit_date]).to eq('2025-07-13T04:00:00.000Z')
        expect(first_dispense[:facility_name]).to eq('SLC4')
        expect(first_dispense[:instructions]).to eq('APPLY TEASPOONFUL(S) TO THE AFFECTED AREA EVERY DAY')
        expect(first_dispense[:quantity]).to eq(1)
        expect(first_dispense[:medication_name]).to eq('COAL TAR 2.5% TOP SOLN')
        expect(first_dispense[:id]).to eq('rf-1')
        expect(first_dispense[:prescription_number]).to eq('RX001')
        expect(first_dispense[:cmop_division_phone]).to eq('800-555-0100')
        expect(first_dispense[:cmop_ndc_number]).to eq('12345-678-90')
        expect(first_dispense[:remarks]).to eq('Handle with care')
        expect(first_dispense[:dial_cmop_division_phone]).to eq('8005550100')
        expect(first_dispense[:disclaimer]).to eq('This is a test disclaimer')
      end
    end

    context 'with Oracle Health prescriptions containing dispenses' do
      let(:oracle_medication_with_dispenses) do
        oracle_health_medication_data.merge(
          'contained' => [
            {
              'resourceType' => 'MedicationDispense',
              'id' => 'dispense-1',
              'status' => 'completed',
              'whenHandedOver' => '2025-01-15T10:00:00Z',
              'quantity' => { 'value' => 30 },
              'location' => { 'display' => '648-PHARMACY' },
              'dosageInstruction' => [
                {
                  'text' => 'See Instructions, daily, 1 EA, 0 Refill(s)'
                }
              ],
              'medicationCodeableConcept' => {
                'text' => 'amLODIPine (amLODIPine 5 mg tablet)'
              }
            },
            {
              'resourceType' => 'MedicationDispense',
              'id' => 'dispense-2',
              'status' => 'completed',
              'whenHandedOver' => '2025-01-29T14:30:00Z',
              'quantity' => { 'value' => 30 },
              'location' => { 'display' => '648-PHARMACY' },
              'dosageInstruction' => [
                {
                  'text' => 'See Instructions, daily, 1 EA, 0 Refill(s)'
                }
              ],
              'medicationCodeableConcept' => {
                'text' => 'amLODIPine (amLODIPine 5 mg tablet)'
              }
            }
          ]
        )
      end

      let(:response_with_oracle_dispenses) do
        {
          'vista' => nil,
          'oracle-health' => {
            'entry' => [
              {
                'resource' => oracle_medication_with_dispenses
              }
            ]
          }
        }
      end

      before do
        allow(Rails.cache).to receive(:read).with('uhd:facility_names:648').and_return('Portland VA Medical Center')
        allow(Rails.cache).to receive(:exist?).with('uhd:facility_names:648').and_return(true)
      end

      it 'includes dispenses in Oracle Health prescriptions' do
        prescriptions = subject.parse(response_with_oracle_dispenses)

        expect(prescriptions.size).to eq(1)
        oracle_prescription = prescriptions.first

        expect(oracle_prescription.dispenses).to be_an(Array)
        expect(oracle_prescription.dispenses.size).to eq(2)

        first_dispense = oracle_prescription.dispenses.first
        expect(first_dispense[:status]).to eq('completed')
        expect(first_dispense[:refill_date]).to eq('2025-01-15T10:00:00Z')
        expect(first_dispense[:facility_name]).to eq('Portland VA Medical Center')
        expect(first_dispense[:instructions]).to eq('See Instructions, daily, 1 EA, 0 Refill(s)')
        expect(first_dispense[:quantity]).to eq(30)
        expect(first_dispense[:medication_name]).to eq('amLODIPine (amLODIPine 5 mg tablet)')
        expect(first_dispense[:id]).to eq('dispense-1')
        # Verify Vista-only fields are nil for Oracle Health
        expect(first_dispense[:refill_submit_date]).to be_nil
        expect(first_dispense[:prescription_number]).to be_nil
        expect(first_dispense[:cmop_division_phone]).to be_nil
        expect(first_dispense[:cmop_ndc_number]).to be_nil
        expect(first_dispense[:remarks]).to be_nil
        expect(first_dispense[:dial_cmop_division_phone]).to be_nil
        expect(first_dispense[:disclaimer]).to be_nil
      end
    end

    context 'with prescriptions without dispenses' do
      it 'includes empty dispenses array for Vista prescriptions without rxRFRecords' do
        prescriptions = subject.parse(unified_response)

        vista_prescription = prescriptions.find { |p| p.prescription_id == '28148665' }
        expect(vista_prescription.dispenses).to eq([])
      end

      it 'includes empty dispenses array for Oracle Health prescriptions without MedicationDispense' do
        oracle_only_response = {
          'vista' => nil,
          'oracle-health' => {
            'entry' => [
              {
                'resource' => {
                  'resourceType' => 'MedicationRequest',
                  'id' => 'no-dispenses',
                  'status' => 'active',
                  'authoredOn' => '2025-01-29T19:41:43Z',
                  'medicationCodeableConcept' => {
                    'text' => 'Test Medication'
                  }
                }
              }
            ]
          }
        }

        prescriptions = subject.parse(oracle_only_response)
        expect(prescriptions.size).to eq(1)
        expect(prescriptions.first.dispenses).to eq([])
      end
    end

    context 'with missing provider information' do
      let(:vista_medication_no_provider) do
        vista_medication_data.except('providerLastName', 'providerFirstName')
      end

      let(:oracle_medication_no_requester) do
        oracle_health_medication_data.except('requester')
      end

      let(:response_with_missing_providers) do
        {
          'vista' => { 'medicationList' => { 'medication' => [vista_medication_no_provider] } },
          'oracle-health' => {
            'entry' => [
              {
                'resource' => oracle_medication_no_requester
              }
            ]
          }
        }
      end

      it 'handles missing provider data gracefully' do
        prescriptions = subject.parse(response_with_missing_providers)

        expect(prescriptions.size).to eq(2)
        vista_prescription = prescriptions.find { |p| p.prescription_id == '28148665' }
        oracle_prescription = prescriptions.find { |p| p.prescription_id == '15208365735' }

        expect(vista_prescription.provider_name).to be_nil
        expect(oracle_prescription.provider_name).to be_nil
      end

      it 'handles partial VistA provider data (only last name)' do
        partial_data = vista_medication_data.except('providerFirstName')
        response = {
          'vista' => { 'medicationList' => { 'medication' => [partial_data] } },
          'oracle-health' => nil
        }

        prescriptions = subject.parse(response)
        expect(prescriptions.first.provider_name).to eq('SMITH')
      end

      it 'handles partial VistA provider data (only first name)' do
        partial_data = vista_medication_data.except('providerLastName')
        response = {
          'vista' => { 'medicationList' => { 'medication' => [partial_data] } },
          'oracle-health' => nil
        }

        prescriptions = subject.parse(response)
        expect(prescriptions.first.provider_name).to eq('JOHN')
      end
    end

    context 'dial_cmop_division_phone field' do
      it 'maps dialCmopDivisionPhone from Vista prescriptions' do
        prescriptions = subject.parse(unified_response)
        vista_prescription = prescriptions.find { |p| p.prescription_id == '28148665' }

        expect(vista_prescription.dial_cmop_division_phone).to eq('555-DIAL')
      end

      it 'sets dial_cmop_division_phone to null for Oracle Health prescriptions' do
        prescriptions = subject.parse(unified_response)
        oracle_prescription = prescriptions.find { |p| p.prescription_id == '15208365735' }

        expect(oracle_prescription.dial_cmop_division_phone).to be_nil
      end
    end

    context 'with remarks field' do
      context 'VistA prescriptions' do
        it 'includes remarks from VistA data' do
          prescriptions = subject.parse(unified_response)
          vista_prescription = prescriptions.find { |p| p.prescription_id == '28148665' }

          expect(vista_prescription.remarks).to eq('TEST REMARKS FOR VISTA')
        end

        it 'returns nil when remarks is not present' do
          vista_data_without_remarks = vista_medication_data.merge('remarks' => nil)
          response = {
            'vista' => { 'medicationList' => { 'medication' => [vista_data_without_remarks] } },
            'oracle-health' => nil
          }

          prescriptions = subject.parse(response)
          expect(prescriptions.first.remarks).to be_nil
        end
      end

      context 'Oracle Health prescriptions' do
        it 'concatenates all note.text fields' do
          prescriptions = subject.parse(unified_response)
          oracle_prescription = prescriptions.find { |p| p.prescription_id == '15208365735' }

          expect(oracle_prescription.remarks).to eq('Take with food. May cause dizziness.')
        end

        it 'returns nil when note array is empty' do
          oracle_data_without_notes = oracle_health_medication_data.merge('note' => [])
          response = {
            'vista' => nil,
            'oracle-health' => {
              'entry' => [
                {
                  'resource' => oracle_data_without_notes
                }
              ]
            }
          }

          prescriptions = subject.parse(response)
          expect(prescriptions.first.remarks).to be_nil
        end

        it 'returns nil when note is not present' do
          oracle_data_without_notes = oracle_health_medication_data.dup
          oracle_data_without_notes.delete('note')
          response = {
            'vista' => nil,
            'oracle-health' => {
              'entry' => [
                {
                  'resource' => oracle_data_without_notes
                }
              ]
            }
          }

          prescriptions = subject.parse(response)
          expect(prescriptions.first.remarks).to be_nil
        end

        it 'handles single note' do
          oracle_data_with_single_note = oracle_health_medication_data.merge(
            'note' => [{ 'text' => 'Single note text' }]
          )
          response = {
            'vista' => nil,
            'oracle-health' => {
              'entry' => [
                {
                  'resource' => oracle_data_with_single_note
                }
              ]
            }
          }

          prescriptions = subject.parse(response)
          expect(prescriptions.first.remarks).to eq('Single note text')
        end

        it 'handles multiple notes' do
          oracle_data_with_multiple_notes = oracle_health_medication_data.merge(
            'note' => [
              { 'text' => 'First note' },
              { 'text' => 'Second note' },
              { 'text' => 'Third note' }
            ]
          )
          response = {
            'vista' => nil,
            'oracle-health' => {
              'entry' => [
                {
                  'resource' => oracle_data_with_multiple_notes
                }
              ]
            }
          }

          prescriptions = subject.parse(response)
          expect(prescriptions.first.remarks).to eq('First note Second note Third note')
        end

        it 'filters out notes without text field' do
          oracle_data_with_mixed_notes = oracle_health_medication_data.merge(
            'note' => [
              { 'text' => 'Valid note' },
              { 'authorReference' => 'Practitioner/123' },
              { 'text' => 'Another valid note' }
            ]
          )
          response = {
            'vista' => nil,
            'oracle-health' => {
              'entry' => [
                {
                  'resource' => oracle_data_with_mixed_notes
                }
              ]
            }
          }

          prescriptions = subject.parse(response)
          expect(prescriptions.first.remarks).to eq('Valid note Another valid note')
        end

        it 'filters out notes with empty text' do
          oracle_data_with_empty_text = oracle_health_medication_data.merge(
            'note' => [
              { 'text' => 'Valid note' },
              { 'text' => '' },
              { 'text' => 'Another valid note' }
            ]
          )
          response = {
            'vista' => nil,
            'oracle-health' => {
              'entry' => [
                {
                  'resource' => oracle_data_with_empty_text
                }
              ]
            }
          }

          prescriptions = subject.parse(response)
          expect(prescriptions.first.remarks).to eq('Valid note Another valid note')
        end
      end
    end
  end

  describe 'V2 status mapping consolidation' do
    let(:adapter) { subject }

    let(:vista_medication_with_refill_status) do
      vista_medication_data.merge(
        'prescriptionId' => 'vista-with-status',
        'refillStatus' => 'active',
        'dispStatus' => 'Active'
      )
    end

    let(:oracle_medication_request) do
      oracle_health_medication_data.merge(
        'id' => 'oracle-request',
        'status' => 'active',
        'dispenseRequest' => {
          'numberOfRepeatsAllowed' => 5,
          'quantity' => { 'value' => 30 }
        }
      )
    end

    let(:unified_body) do
      {
        'vista' => {
          'medicationList' => {
            'medication' => [vista_medication_data.merge('dispStatus' => 'Active')]
          }
        },
        'oracle-health' => {
          'entry' => [{ 'resource' => oracle_health_medication_data }]
        }
      }
    end

    let(:combined_body) do
      {
        'vista' => {
          'medicationList' => {
            'medication' => [vista_medication_with_refill_status]
          }
        },
        'oracle-health' => {
          'entry' => [{ 'resource' => oracle_medication_request }]
        }
      }
    end

    let(:vista_active) do
      vista_medication_data.merge(
        'prescriptionId' => 'vista-active',
        'refillStatus' => 'active',
        'dispStatus' => nil
      )
    end

    let(:vista_expired) do
      vista_medication_data.merge(
        'prescriptionId' => 'vista-expired',
        'refillStatus' => 'expired',
        'dispStatus' => nil
      )
    end

    let(:vista_discontinued) do
      vista_medication_data.merge(
        'prescriptionId' => 'vista-discontinued',
        'refillStatus' => 'discontinued',
        'dispStatus' => nil
      )
    end

    let(:vista_hold) do
      vista_medication_data.merge(
        'prescriptionId' => 'vista-hold',
        'refillStatus' => 'hold',
        'dispStatus' => nil
      )
    end

    let(:vista_provider_hold) do
      vista_medication_data.merge(
        'prescriptionId' => 'vista-provider-hold',
        'refillStatus' => 'providerHold',
        'dispStatus' => nil
      )
    end

    let(:vista_submitted) do
      vista_medication_data.merge(
        'prescriptionId' => 'vista-submitted',
        'refillStatus' => 'submitted',
        'dispStatus' => nil
      )
    end

    let(:oracle_active) do
      oracle_health_medication_data.merge(
        'id' => 'oracle-active',
        'status' => 'active',
        'dispenseRequest' => {
          'numberOfRepeatsAllowed' => 5,
          'quantity' => { 'value' => 30 }
        }
      )
    end

    let(:oracle_on_hold) do
      oracle_health_medication_data.merge(
        'id' => 'oracle-on-hold',
        'status' => 'on-hold',
        'dispenseRequest' => {
          'numberOfRepeatsAllowed' => 5,
          'quantity' => { 'value' => 30 }
        }
      )
    end

    let(:oracle_stopped) do
      oracle_health_medication_data.merge(
        'id' => 'oracle-stopped',
        'status' => 'stopped',
        'dispenseRequest' => {
          'numberOfRepeatsAllowed' => 0,
          'quantity' => { 'value' => 30 }
        }
      )
    end

    let(:vista_response) do
      {
        'vista' => {
          'medicationList' => {
            'medication' => [
              vista_active,
              vista_expired,
              vista_discontinued,
              vista_hold,
              vista_provider_hold,
              vista_submitted
            ]
          }
        },
        'oracle-health' => nil
      }
    end

    let(:oracle_response) do
      {
        'vista' => nil,
        'oracle-health' => {
          'entry' => [
            { 'resource' => oracle_active },
            { 'resource' => oracle_on_hold },
            { 'resource' => oracle_stopped }
          ]
        }
      }
    end

    let(:combined_response) do
      {
        'vista' => {
          'medicationList' => {
            'medication' => [vista_active, vista_expired]
          }
        },
        'oracle-health' => {
          'entry' => [
            { 'resource' => oracle_active },
            { 'resource' => oracle_on_hold }
          ]
        }
      }
    end

    let(:vista_only_body) do
      {
        'vista' => {
          'medicationList' => {
            'medication' => [vista_medication_with_refill_status]
          }
        }
      }
    end

    let(:oracle_only_body) do
      {
        'oracle-health' => {
          'entry' => [{ 'resource' => oracle_medication_request }]
        }
      }
    end

    before do
      allow(Flipper).to receive(:enabled?).with(:mhv_medications_display_pending_meds, user).and_return(false)
    end

    context 'when mhv_medications_v2_status_mapping flag is disabled' do
      before do
        allow(Flipper).to receive(:enabled?).with(:mhv_medications_v2_status_mapping, user).and_return(false)
      end

      it 'returns legacy refill_status values for VistA prescriptions' do
        prescriptions = subject.parse(vista_response)

        statuses = prescriptions.map(&:refill_status)
        expect(statuses).to include('active', 'expired', 'discontinued', 'hold', 'providerHold', 'submitted')
      end

      it 'returns legacy refill_status values for Oracle Health prescriptions' do
        prescriptions = subject.parse(oracle_response)

        # Oracle adapter normalizes FHIR status to legacy VistA-style status
        statuses = prescriptions.map(&:refill_status)
        expect(statuses).to include('active', 'providerHold', 'discontinued')
      end

      it 'does not apply V2 status mapping to combined prescriptions' do
        prescriptions = subject.parse(combined_response)

        statuses = prescriptions.map(&:refill_status)
        # Should have legacy statuses, not V2 format
        expect(statuses).not_to include('Active', 'Inactive', 'Active: On hold')
        expect(statuses).to include('active', 'expired', 'providerHold')
      end
    end

    context 'when mhv_medications_v2_status_mapping flag is enabled' do
      before do
        allow(Flipper).to receive(:enabled?).with(:mhv_medications_v2_status_mapping, user).and_return(true)
      end

      describe 'VistA prescription status mapping' do
        context 'when dispStatus is present (V2 mapping applied to dispStatus)' do
          it 'maps Active dispStatus to Active' do
            vista_medication_with_refill_status['dispStatus'] = 'Active'

            result = adapter.parse(vista_only_body)

            expect(result.first.disp_status).to eq('Active')
          end

          it 'maps Expired dispStatus to Inactive' do
            vista_medication_with_refill_status['dispStatus'] = 'Expired'

            result = adapter.parse(vista_only_body)

            expect(result.first.disp_status).to eq('Inactive')
          end

          it 'maps Discontinued dispStatus to Inactive' do
            vista_medication_with_refill_status['dispStatus'] = 'Discontinued'

            result = adapter.parse(vista_only_body)

            expect(result.first.disp_status).to eq('Inactive')
          end

          it 'maps Active: On hold dispStatus to Inactive' do
            vista_medication_with_refill_status['dispStatus'] = 'Active: On hold'

            result = adapter.parse(vista_only_body)

            expect(result.first.disp_status).to eq('Inactive')
          end

          it 'maps Active: Submitted dispStatus to In progress' do
            vista_medication_with_refill_status['dispStatus'] = 'Active: Submitted'

            result = adapter.parse(vista_only_body)

            expect(result.first.disp_status).to eq('In progress')
          end

          it 'maps Active: Refill in Process dispStatus to In progress' do
            vista_medication_with_refill_status['dispStatus'] = 'Active: Refill in Process'

            result = adapter.parse(vista_only_body)

            expect(result.first.disp_status).to eq('In progress')
          end

          it 'handles unknown dispStatus by returning Status not available' do
            vista_medication_with_refill_status['dispStatus'] = 'SomeUnknownStatus'

            result = adapter.parse(vista_only_body)

            expect(result.first.disp_status).to eq('Status not available')
          end
        end

        context 'when dispStatus is null/empty (derived from refillStatus, then V2 mapped)' do
          it 'derives Active from active refillStatus, maps to Active' do
            vista_medication_with_refill_status['refillStatus'] = 'active'
            vista_medication_with_refill_status['dispStatus'] = nil

            result = adapter.parse(vista_only_body)

            expect(result.first.disp_status).to eq('Active')
          end

          it 'derives Expired from expired refillStatus, maps to Inactive' do
            vista_medication_with_refill_status['refillStatus'] = 'expired'
            vista_medication_with_refill_status['dispStatus'] = nil

            result = adapter.parse(vista_only_body)

            expect(result.first.disp_status).to eq('Inactive')
          end

          it 'derives Discontinued from discontinued refillStatus, maps to Inactive' do
            vista_medication_with_refill_status['refillStatus'] = 'discontinued'
            vista_medication_with_refill_status['dispStatus'] = nil

            result = adapter.parse(vista_only_body)

            expect(result.first.disp_status).to eq('Inactive')
          end

          it 'derives Active: On hold from hold refillStatus, maps to Inactive' do
            vista_medication_with_refill_status['refillStatus'] = 'hold'
            vista_medication_with_refill_status['dispStatus'] = nil

            result = adapter.parse(vista_only_body)

            expect(result.first.disp_status).to eq('Inactive')
          end

          it 'derives Active: Submitted from submitted refillStatus, maps to In progress' do
            vista_medication_with_refill_status['refillStatus'] = 'submitted'
            vista_medication_with_refill_status['dispStatus'] = nil

            result = adapter.parse(vista_only_body)

            expect(result.first.disp_status).to eq('In progress')
          end
        end
      end

      context 'Oracle Health prescription status mapping' do
        it 'maps active (with refills) to Active' do
          oracle_medication_request['status'] = 'active'

          result = adapter.parse(oracle_only_body)

          expect(result.first.disp_status).to eq('Active')
        end

        it 'maps on-hold to Inactive (V2 mapped from Active: On hold)' do
          oracle_medication_request['status'] = 'on-hold'

          result = adapter.parse(oracle_only_body)

          expect(result.first.disp_status).to eq('Inactive')
        end

        it 'maps stopped/discontinued to Inactive' do
          oracle_medication_request['status'] = 'stopped'

          result = adapter.parse(oracle_only_body)

          expect(result.first.disp_status).to eq('Inactive')
        end
      end

      context 'combined VistA and Oracle Health prescriptions' do
        it 'applies V2 status mapping to ALL prescriptions from both sources' do
          result = adapter.parse(combined_body)

          # All prescriptions should have V2 status values
          v2_statuses = ['Active', 'In progress', 'Inactive', 'Transferred', 'Status not available']
          result.each do |rx|
            expect(rx.disp_status).to be_in(v2_statuses)
          end
        end

        it 'is the single consolidation point for status mapping' do
          # This test verifies that V2 mapping happens once at the adapter level,
          # not in individual source adapters
          vista_only = adapter.parse({
                                       'vista' => {
                                         'medicationList' => {
                                           'medication' => [vista_medication_with_refill_status]
                                         }
                                       }
                                     })

          oracle_only = adapter.parse({
                                        'oracle-health' => {
                                          'entry' => [{ 'resource' => oracle_medication_request }]
                                        }
                                      })

          # Both should have V2 status values
          v2_statuses = ['Active', 'In progress', 'Inactive', 'Transferred', 'Status not available']
          expect(v2_statuses).to include(vista_only.first.disp_status)
          expect(v2_statuses).to include(oracle_only.first.disp_status)
        end
      end

      context 'disp_status mapping' do
        it 'maps VistA dispStatus values to V2 format' do
          # VistA prescriptions come with dispStatus already set
          vista_medication_with_refill_status['dispStatus'] = 'Active: Refill in Process'

          result = adapter.parse({
                                   'vista' => {
                                     'medicationList' => {
                                       'medication' => [vista_medication_with_refill_status]
                                     }
                                   }
                                 })

          # V2 mapping: 'Active: Refill in Process' -> 'In progress'
          expect(result.first.disp_status).to eq('In progress')
        end
      end
    end

    context 'status mapping edge cases' do
      before do
        allow(Flipper).to receive(:enabled?).with(:mhv_medications_v2_status_mapping, user).and_return(true)
      end

      let(:edge_case_vista_medication) do
        vista_medication_with_refill_status.merge(
          'refillStatus' => nil,
          'dispStatus' => nil
        )
      end

      it 'handles nil refill_status gracefully' do
        edge_case_vista_medication['refillStatus'] = nil
        edge_case_vista_medication['dispStatus'] = nil

        result = adapter.parse({
                                 'vista' => {
                                   'medicationList' => {
                                     'medication' => [edge_case_vista_medication]
                                   }
                                 }
                               })

        # When both are nil, disp_status stays nil (no derivation or mapping happens)
        expect(result.first.disp_status).to be_nil
      end

      it 'handles empty string refill_status gracefully' do
        edge_case_vista_medication['refillStatus'] = ''
        edge_case_vista_medication['dispStatus'] = ''

        result = adapter.parse({
                                 'vista' => {
                                   'medicationList' => {
                                     'medication' => [edge_case_vista_medication]
                                   }
                                 }
                               })

        # Empty string is treated as blank, stays as-is
        expect(result.first.disp_status).to eq('')
      end

      it 'is case-insensitive for status matching' do
        edge_case_vista_medication['refillStatus'] = 'ACTIVE'
        edge_case_vista_medication['dispStatus'] = 'ACTIVE'

        result = adapter.parse({
                                 'vista' => {
                                   'medicationList' => {
                                     'medication' => [edge_case_vista_medication]
                                   }
                                 }
                               })

        # Case-insensitive matching: 'ACTIVE' -> 'Active' (V2)
        expect(result.first.disp_status).to eq('Active')
      end
    end
  end
end
