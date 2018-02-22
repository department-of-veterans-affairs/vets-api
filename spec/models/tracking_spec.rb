# frozen_string_literal: true

require 'rails_helper'

describe Tracking do
  let(:tracking_attributes) { attributes_for(:tracking) }

  context 'with valid attributes' do
    subject { described_class.new(tracking_attributes) }

    it 'has attributes' do
      expect(subject).to have_attributes(prescription_name: 'Drug 1 250MG TAB', prescription_number: '2719324',
                                         facility_name: 'ABC123', rx_info_phone_number: '(333)772-1111',
                                         ndc_number: '12345678910', delivery_service: 'UPS',
                                         tracking_number: '01234567890')
    end

    it 'has date attribute' do
      expect(subject).to have_attributes(shipped_date: Time.parse('Thu, 12 Oct 2016 00:00:00 EDT').in_time_zone)
    end
  end

  context 'additional attribute for prescription_id' do
    let(:tracking_with_prescription_id) { described_class.new(attributes_for(:tracking, prescription_id: '1')) }

    it 'assigns prescription id' do
      expect(tracking_with_prescription_id.prescription_id).to eq(1)
    end

    context 'it sorts' do
      let(:t1) { tracking_with_prescription_id }
      let(:t2) { tracking_with_prescription_id }
      let(:t3) { described_class.new(attributes_for(:tracking, prescription_id: '2', shipped_date: Time.now.utc)) }
      let(:t4) { described_class.new(attributes_for(:tracking, :oldest, prescription_id: '3')) }

      subject { [t1, t2, t3, t4] }

      it 'sorts by shipped_date by default' do
        expect(subject.sort.map(&:prescription_id))
          .to eq([2, 1, 1, 3])
      end

      it 'sorts by sort_by field' do
        expect(subject.sort_by(&:prescription_id).map(&:prescription_id))
          .to eq([1, 1, 2, 3])
      end
    end
  end
end
