# frozen_string_literal: true

require 'rails_helper'
require 'unified_health_data/adapters/vista_prescription_adapter'

RSpec.describe UnifiedHealthData::Adapters::VistaPrescriptionAdapter do
  subject { described_class.new }

  let(:base_medication_data) do
    {
      'prescriptionId' => '13650541',
      'prescriptionName' => 'PAROXETINE HCL 30MG TAB',
      'prescriptionNumber' => '2719551',
      'ndcNumber' => '00781171601',
      'refillStatus' => 'active',
      'isRefillable' => true,
      'isTrackable' => true
    }
  end

  describe '#parse with tracking data' do
    context 'when medication has tracking information' do
      let(:tracking_info) do
        [
          {
            'shippedDate' => 'Wed, 07 Sep 2016 00:00:00 EDT',
            'deliveryService' => 'USPS',
            'trackingNumber' => '657068347565',
            'otherPrescriptionListIncluded' => [
              {
                'prescriptionName' => 'SIROLIMUS 1MG TAB',
                'prescriptionNumber' => '2719536'
              }
            ]
          }
        ]
      end

      let(:medication_with_tracking) do
        base_medication_data.merge('trackingInfo' => tracking_info)
      end

      it 'transforms tracking data to the specified format' do
        prescription = subject.parse(medication_with_tracking)

        expect(prescription.tracking).to be_an(Array)
        expect(prescription.tracking.length).to eq(1)

        tracking_item = prescription.tracking.first
        expect(tracking_item).to include(
          prescriptionName: 'PAROXETINE HCL 30MG TAB',
          prescriptionNumber: '2719551',
          ndcNumber: '00781171601',
          prescriptionId: 13650541,
          trackingNumber: '657068347565',
          shippedDate: '2016-09-07T00:00:00.000Z',
          carrier: 'USPS',
          otherPrescriptions: [
            {
              prescriptionName: 'SIROLIMUS 1MG TAB',
              prescriptionNumber: '2719536'
            }
          ]
        )
      end
    end

    context 'when medication has multiple tracking entries' do
      let(:multiple_tracking_info) do
        [
          {
            'shippedDate' => 'Wed, 07 Sep 2016 00:00:00 EDT',
            'deliveryService' => 'USPS',
            'trackingNumber' => '657068347565',
            'otherPrescriptionListIncluded' => []
          },
          {
            'shippedDate' => 'Wed, 06 Jul 2016 00:00:00 EDT',
            'deliveryService' => 'UPS',
            'trackingNumber' => '345787647659',
            'otherPrescriptionListIncluded' => [
              {
                'prescriptionName' => 'CARBAMAZEPINE (TEGRETOL) 200MG TAB',
                'prescriptionNumber' => '2719552'
              }
            ]
          }
        ]
      end

      let(:medication_with_multiple_tracking) do
        base_medication_data.merge('trackingInfo' => multiple_tracking_info)
      end

      it 'processes all tracking entries' do
        prescription = subject.parse(medication_with_multiple_tracking)

        expect(prescription.tracking.length).to eq(2)
        
        first_tracking = prescription.tracking.first
        expect(first_tracking[:carrier]).to eq('USPS')
        expect(first_tracking[:otherPrescriptions]).to eq([])

        second_tracking = prescription.tracking.last
        expect(second_tracking[:carrier]).to eq('UPS')
        expect(second_tracking[:otherPrescriptions].length).to eq(1)
      end
    end

    context 'when medication has no tracking information' do
      it 'returns empty tracking array' do
        prescription = subject.parse(base_medication_data)

        expect(prescription.tracking).to eq([])
      end
    end

    context 'when trackingInfo is not an array' do
      let(:medication_with_invalid_tracking) do
        base_medication_data.merge('trackingInfo' => 'not an array')
      end

      it 'returns empty tracking array' do
        prescription = subject.parse(medication_with_invalid_tracking)

        expect(prescription.tracking).to eq([])
      end
    end
  end

  describe '#format_shipped_date' do
    it 'converts MHV date format to ISO 8601' do
      date_string = 'Wed, 07 Sep 2016 00:00:00 EDT'
      result = subject.send(:format_shipped_date, date_string)

      expect(result).to eq('2016-09-07T04:00:00.000Z') # EDT is UTC-4
    end

    it 'handles nil input' do
      result = subject.send(:format_shipped_date, nil)

      expect(result).to be_nil
    end

    it 'handles invalid date format gracefully' do
      allow(Rails.logger).to receive(:warn)

      result = subject.send(:format_shipped_date, 'invalid date')

      expect(result).to be_nil
      expect(Rails.logger).to have_received(:warn).with(/Unable to parse shipped date: invalid date/)
    end
  end

  describe '#build_other_prescriptions' do
    it 'transforms other prescriptions list' do
      other_prescriptions = [
        {
          'prescriptionName' => 'MEDICATION A',
          'prescriptionNumber' => '123456'
        },
        {
          'prescriptionName' => 'MEDICATION B',
          'prescriptionNumber' => '789012'
        }
      ]

      result = subject.send(:build_other_prescriptions, other_prescriptions)

      expect(result).to eq([
        {
          prescriptionName: 'MEDICATION A',
          prescriptionNumber: '123456'
        },
        {
          prescriptionName: 'MEDICATION B',
          prescriptionNumber: '789012'
        }
      ])
    end

    it 'handles nil input' do
      result = subject.send(:build_other_prescriptions, nil)

      expect(result).to eq([])
    end

    it 'handles non-array input' do
      result = subject.send(:build_other_prescriptions, 'not an array')

      expect(result).to eq([])
    end
  end
end