# frozen_string_literal: true
require 'rails_helper'
require 'rx/parser'

describe Tracking do
  let(:original_camel_cased_json) { File.read('spec/support/fixtures/rx_tracking_1435525.json') }
  let(:parsed_json_objects) { Rx::Parser.new(JSON.parse(original_camel_cased_json)).parse! }
  let(:parsed_json_object) { parsed_json_objects[:data].first }

  context 'with valid attributes' do
    subject { described_class.new(parsed_json_object) }

    it 'has attributes' do
      expect(subject).to have_attributes(prescription_name: 'PROBUCOL 250MG TAB', prescription_number: '2719324',
                                         facility_name: 'DAYT3', rx_info_phone_number: '(444)772-0987',
                                         ndc_number: '00078036864', delivery_service: 'UPS',
                                         tracking_number: '31457644862')
    end

    it 'has date attribute' do
      expect(subject).to have_attributes(shipped_date: Time.parse('Thu, 21 Apr 2016 00:00:00 EDT').in_time_zone)
    end
  end

  context 'additional attribute for prescription_id' do
    let(:tracking_with_prescription_id) { described_class.new(data_attr_merge(prescription_id: '1')) }

    it 'assigns prescription id' do
      expect(tracking_with_prescription_id.prescription_id).to eq(1)
    end

    context 'it sorts' do
      let(:t1) { tracking_with_prescription_id }
      let(:t2) { tracking_with_prescription_id }
      let(:t3) { described_class.new(data_attr_merge(prescription_id: '2', shipped_date: Time.now.utc)) }
      let(:t4) { described_class.new(data_attr_merge(prescription_id: '3', shipped_date: 1.year.ago.utc)) }

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

  def data_attr_merge(attributes = {})
    data = parsed_json_object
    parsed_json_object.merge(data: data.merge(attributes))
  end
end
