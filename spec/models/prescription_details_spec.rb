# frozen_string_literal: true

require 'rails_helper'

describe PrescriptionDetails do
  let(:prescription_details_attributes) { attributes_for(:prescription_details) }

  context 'with valid attributes' do
    subject { described_class.new(prescription_details_attributes) }

    it 'has attributes' do
      expect(subject).to have_attributes(refill_status: 'active', refill_remaining: 9, facility_name: 'ABC1223',
                                         is_refillable: true, is_trackable: false, prescription_id: 1_435_525,
                                         quantity: 10,  prescription_number: '2719324',
                                         prescription_name: 'Drug 1 250MG TAB', station_number: '23',
                                         cmop_division_phone: nil, in_cerner_transition: false,
                                         not_refillable_display_message: 'test',
                                         cmop_ndc_number: nil, user_id: 16_955_936, provider_first_name: 'MOHAMMAD',
                                         provider_last_name: 'ISLAM', remarks: nil, division_name: 'DAYTON',
                                         institution_id: nil, dial_cmop_division_phone: '',
                                         disp_status: 'Active: Refill in Process', ndc: '00173_9447_00',
                                         reason: nil, prescription_number_index: 'RX', prescription_source: 'RX',
                                         disclaimer: nil, indication_for_use: nil, indication_for_use_flag: nil,
                                         category: 'Rx Medication', tracking: false, color: nil, shape: nil,
                                         back_imprint: nil, front_imprint: nil)
    end

    it 'has additional aliased rubyesque methods' do
      expect(subject).to have_attributes(trackable?: false, refillable?: true)
    end

    it 'has date attributes' do
      expect(subject).to have_attributes(refill_submit_date: Time.parse('Tue, 26 Apr 2016 00:00:00 EDT').in_time_zone,
                                         refill_date: Time.parse('Thu, 21 Apr 2016 00:00:00 EDT').in_time_zone,
                                         ordered_date: Time.parse('Tue, 29 Mar 2016 00:00:00 EDT').in_time_zone,
                                         expiration_date: Time.parse('Thu, 30 Mar 2017 00:00:00 EDT').in_time_zone,
                                         dispensed_date: Time.parse('Thu, 21 Apr 2016 00:00:00 EDT').in_time_zone,
                                         modified_date: Time.parse('2023-08-11T15:56:58.000Z').in_time_zone)
    end

    it 'has method attribute sorted_dispensed_date' do
      expect(subject).to have_attributes(sorted_dispensed_date: Date.parse('Thu, 21 Apr 2016'))
    end
  end

  context 'sorted_dispensed_date test cases with dispensed_date' do
    subject do
      described_class.new(attributes_for(:prescription_details,
                                         dispensed_date: Time.parse('Thu, 21 Apr 2016 00:00:00 EDT').in_time_zone,
                                         rx_rf_records: nil))
    end

    it 'sorted_dispensed_date should be same as dispensed_date' do
      expect(subject).to have_attributes(sorted_dispensed_date: Date.parse('Thu, 21 Apr 2016'))
    end
  end

  context 'sorted_dispensed_date test cases with sorted_dispensed_date' do
    subject { described_class.new(prescription_details_attributes) }

    it 'sorted_dispensed_date should be same as sorted_dispensed_date' do
      expect(subject).to have_attributes(sorted_dispensed_date: Date.parse('Thu, 21 Apr 2016'))
    end
  end

  context 'sorted_dispensed_date test cases with nil' do
    subject do
      described_class.new(attributes_for(:prescription_details,
                                         dispensed_date: nil,
                                         rx_rf_records: [['rf_record',
                                                          [{ refill_date: 'Sat, 15 Jul 2023 00:00:00 EDT',
                                                             dispensed_date: nil }]]]))
    end

    it 'sorted_dispensed_date should be nil' do
      expect(subject.sorted_dispensed_date).to be_nil
    end
  end
end
