# frozen_string_literal: true

require 'rails_helper'

RSpec.describe MyHealth::PrescriptionHelper::Sorting do
  let(:sorting_instance) do
    Class.new do
      include MyHealth::PrescriptionHelper::Sorting
      public :apply_sorting
    end.new
  end

  def build_prescription(attrs = {})
    defaults = {
      prescription_name: 'Test Med',
      disp_status: 'Active',
      sorted_dispensed_date: nil,
      prescription_source: 'VA',
      orderable_item: nil
    }
    OpenStruct.new(defaults.merge(attrs))
  end

  def build_resource(records)
    OpenStruct.new(records:, metadata: {})
  end

  describe 'case-insensitive sorting' do
    let(:upper_med) { build_prescription(prescription_name: 'BACITRACIN', disp_status: 'Active') }
    let(:lower_med) { build_prescription(prescription_name: 'atorvastatin', disp_status: 'Active') }
    let(:title_med) { build_prescription(prescription_name: 'Celecoxib', disp_status: 'Active') }

    context 'with alphabetical-rx-name sort' do
      it 'sorts names case-insensitively' do
        resource = build_resource([upper_med, lower_med, title_med])
        result = sorting_instance.apply_sorting(resource, 'alphabetical-rx-name')
        names = result.records.map(&:prescription_name)

        expect(names).to eq(%w[atorvastatin BACITRACIN Celecoxib])
      end
    end

    context 'with default sort' do
      it 'sorts names case-insensitively within the same status' do
        resource = build_resource([upper_med, lower_med, title_med])
        result = sorting_instance.apply_sorting(resource, nil)
        names = result.records.map(&:prescription_name)

        expect(names).to eq(%w[atorvastatin BACITRACIN Celecoxib])
      end
    end

    context 'with Active: Non-VA medications' do
      let(:non_va_upper) do
        build_prescription(
          prescription_name: nil,
          disp_status: 'Active: Non-VA',
          orderable_item: 'DOCUSATE'
        )
      end
      let(:non_va_lower) do
        build_prescription(
          prescription_name: nil,
          disp_status: 'Active: Non-VA',
          orderable_item: 'aspirin'
        )
      end
      let(:non_va_title) do
        build_prescription(
          prescription_name: nil,
          disp_status: 'Active: Non-VA',
          orderable_item: 'Buspirone'
        )
      end

      it 'sorts Non-VA orderable_item names case-insensitively with alphabetical-rx-name' do
        resource = build_resource([non_va_upper, non_va_lower, non_va_title])
        result = sorting_instance.apply_sorting(resource, 'alphabetical-rx-name')
        names = result.records.map(&:orderable_item)

        expect(names).to eq(%w[aspirin Buspirone DOCUSATE])
      end
    end
  end
end
