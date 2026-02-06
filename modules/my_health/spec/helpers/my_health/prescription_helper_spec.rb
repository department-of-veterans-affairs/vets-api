# frozen_string_literal: true

require 'rails_helper'

RSpec.describe MyHealth::PrescriptionHelper::Filtering do
  let(:helper_instance) do
    Class.new { include MyHealth::PrescriptionHelper::Filtering }.new
  end

  def build_prescription(attrs = {})
    defaults = {
      prescription_name: 'Test Med',
      disp_status: 'Active',
      is_refillable: false,
      refill_remaining: 0,
      rx_rf_records: nil,
      expiration_date: nil,
      prescription_source: 'VA'
    }
    OpenStruct.new(defaults.merge(attrs))
  end

  # renewable and filter_data_by_refill_and_renew are made private by module_function,
  # so we call them via send when testing through an included instance.
  describe '#renewable' do
    context 'when disp_status is Active: Parked with nil rx_rf_records' do
      it 'does not raise NoMethodError' do
        item = build_prescription(
          disp_status: 'Active: Parked',
          is_refillable: false,
          refill_remaining: 0,
          rx_rf_records: nil
        )

        expect { helper_instance.send(:renewable, item) }.not_to raise_error
      end

      it 'returns false' do
        item = build_prescription(
          disp_status: 'Active: Parked',
          is_refillable: false,
          refill_remaining: 0,
          rx_rf_records: nil
        )

        expect(helper_instance.send(:renewable, item)).to be false
      end
    end

    context 'when disp_status is Active: Parked with empty rx_rf_records' do
      it 'returns false' do
        item = build_prescription(
          disp_status: 'Active: Parked',
          is_refillable: false,
          refill_remaining: 0,
          rx_rf_records: [{}]
        )

        expect(helper_instance.send(:renewable, item)).to be false
      end
    end

    context 'when disp_status is Active: Parked with non-empty rx_rf_records' do
      it 'returns true' do
        item = build_prescription(
          disp_status: 'Active: Parked',
          is_refillable: false,
          refill_remaining: 0,
          rx_rf_records: [{ expiration_date: Time.zone.today.to_s }]
        )

        expect(helper_instance.send(:renewable, item)).to be true
      end
    end

    context 'when disp_status is Active' do
      it 'returns true when not refillable and no refills remaining' do
        item = build_prescription(
          disp_status: 'Active',
          is_refillable: false,
          refill_remaining: 0
        )

        expect(helper_instance.send(:renewable, item)).to be true
      end
    end

    context 'when disp_status is Expired' do
      it 'returns true when within cut-off date and not refillable' do
        item = build_prescription(
          disp_status: 'Expired',
          is_refillable: false,
          refill_remaining: 0,
          expiration_date: (Time.zone.today - 30.days).to_s
        )

        expect(helper_instance.send(:renewable, item)).to be true
      end

      it 'returns false when past cut-off date' do
        item = build_prescription(
          disp_status: 'Expired',
          is_refillable: false,
          refill_remaining: 0,
          expiration_date: (Time.zone.today - 121.days).to_s
        )

        expect(helper_instance.send(:renewable, item)).to be false
      end
    end

    context 'when item is refillable' do
      it 'returns false' do
        item = build_prescription(
          disp_status: 'Active',
          is_refillable: true,
          refill_remaining: 3
        )

        expect(helper_instance.send(:renewable, item)).to be false
      end
    end
  end

  describe '#filter_data_by_refill_and_renew' do
    it 'does not raise when prescriptions have nil rx_rf_records' do
      items = [
        build_prescription(
          disp_status: 'Active: Parked',
          is_refillable: false,
          refill_remaining: 0,
          rx_rf_records: nil
        )
      ]

      expect { helper_instance.send(:filter_data_by_refill_and_renew, items) }.not_to raise_error
    end
  end
end
