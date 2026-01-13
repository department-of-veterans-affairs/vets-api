# frozen_string_literal: true

require 'rails_helper'

describe Prescription do
  let(:prescription_attributes) { attributes_for(:prescription) }

  context 'with valid attributes' do
    subject { described_class.new(prescription_attributes) }

    it 'has attributes' do
      expect(subject).to have_attributes(refill_status: 'active', refill_remaining: 9, facility_name: 'ABC1223',
                                         is_refillable: true, is_trackable: false, is_renewable: nil,
                                         prescription_id: 1_435_525, quantity: '10', prescription_number: '2719324',
                                         prescription_name: 'Drug 1 250MG TAB', station_number: '23')
    end

    it 'has additional aliased rubyesque methods' do
      expect(subject).to have_attributes(trackable?: false, refillable?: true, renewable?: nil)
    end

    it 'has date attributes' do
      expect(subject).to have_attributes(refill_submit_date: Time.parse('Tue, 26 Apr 2016 00:00:00 EDT').in_time_zone,
                                         refill_date: Time.parse('Thu, 21 Apr 2016 00:00:00 EDT').in_time_zone,
                                         ordered_date: Time.parse('Tue, 29 Mar 2016 00:00:00 EDT').in_time_zone,
                                         expiration_date: Time.parse('Thu, 30 Mar 2017 00:00:00 EDT').in_time_zone,
                                         dispensed_date: Time.parse('Thu, 21 Apr 2016 00:00:00 EDT').in_time_zone)
    end

    context 'inherited methods' do
      it 'responds to to_json' do
        expect(subject.to_json).to be_a(String)
      end
    end
  end

  context 'it sorts' do
    subject { [p1, p2, p3, p4] }

    let(:p1) { described_class.new(prescription_attributes) }
    let(:p2) { described_class.new(prescription_attributes) }
    let(:p3) { described_class.new(attributes_for(:prescription, prescription_id: '2', refill_date: Time.now.utc)) }
    let(:p4) { described_class.new(attributes_for(:prescription, prescription_id: '3', refill_data: 1.year.ago.utc)) }

    it 'sorts by prescription_id by default' do
      expect(subject.sort.map(&:prescription_id))
        .to eq([2, 3, 1_435_525, 1_435_525])
    end

    it 'sorts by sort_by field' do
      expect(subject.sort_by(&:refill_date).map(&:prescription_id))
        .to eq([1_435_525, 1_435_525, 3, 2])
    end
  end
end
