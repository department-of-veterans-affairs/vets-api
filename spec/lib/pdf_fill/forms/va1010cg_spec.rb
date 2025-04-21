# frozen_string_literal: true

require 'rails_helper'
require 'pdf_fill/forms/va1010cg'

describe PdfFill::Forms::Va1010cg do
  include SchemaMatchers

  let(:form_data) do
    get_fixture('pdf_fill/10-10CG/kitchen_sink')
  end

  let(:form_class) do
    PdfFill::Forms::Va1010cg.new(form_data)
  end

  describe '#merge_fields' do
    before do
      allow(Flipper).to receive(:enabled?).with(:caregiver_lookup_facility_name_db).and_return(false)
    end

    it 'merges the right fields' do
      expect(form_class.merge_fields.to_json).to eq(
        get_fixture('pdf_fill/10-10CG/merge_fields').to_json
      )
    end
  end

  describe '#merge_planned_facility_label_helper' do
    context ':caregiver_lookup_facility_name_db disabled' do
      before do
        allow(Flipper).to receive(:enabled?).with(:caregiver_lookup_facility_name_db).and_return(false)
        allow(VetsJsonSchema::CONSTANTS).to receive(:[]).with('caregiverProgramFacilities').and_return(
          {
            'OH' => {
              'code' => '100',
              'label' => 'VA Facility Name'
            }
          }
        )
      end

      context 'plannedClinic is not in vets-json-schema' do
        let(:form_data) do
          {
            'helpers' => {
              'veteran' => {}
            },
            'veteran' => {
              'plannedClinic' => '99'
            }
          }
        end

        it 'sets the plannedClinic to the facility id' do
          form_class.send(:merge_planned_facility_label_helper)
          expect(form_class.form_data['helpers']['veteran']['plannedClinic']).to eq '99'
        end
      end

      context 'plannedClinic is found in vets-json-schema' do
        let(:form_data) do
          {
            'helpers' => {
              'veteran' => {}
            },
            'veteran' => {
              'plannedClinic' => '100'
            }
          }
        end

        it 'sets the plannedClinic to facility id and facility name' do
          form_class.send(:merge_planned_facility_label_helper)
          expect(form_class.form_data['helpers']['veteran']['plannedClinic']).to eq '100 - VA Facility Name'
        end
      end
    end

    context ':caregiver_lookup_facility_name_db enabled' do
      before do
        allow(Flipper).to receive(:enabled?).with(:caregiver_lookup_facility_name_db).and_return(true)
        create(:health_facility, name: 'VA Facility Name',
                                 station_number: '100',
                                 postal_name: 'OH')
      end

      context 'plannedClinic is not in health_facilities table' do
        let(:form_data) do
          {
            'helpers' => {
              'veteran' => {}
            },
            'veteran' => {
              'plannedClinic' => '99'
            }
          }
        end

        it 'sets the plannedClinic to the facility id' do
          form_class.send(:merge_planned_facility_label_helper)
          expect(form_class.form_data['helpers']['veteran']['plannedClinic']).to eq '99'
        end
      end

      context 'plannedClinic is in health_facilities table' do
        let(:form_data) do
          {
            'helpers' => {
              'veteran' => {}
            },
            'veteran' => {
              'plannedClinic' => '100'
            }
          }
        end

        it 'sets the plannedClinic to facility id and facility name' do
          form_class.send(:merge_planned_facility_label_helper)
          expect(form_class.form_data['helpers']['veteran']['plannedClinic']).to eq '100 - VA Facility Name'
        end
      end
    end
  end
end
