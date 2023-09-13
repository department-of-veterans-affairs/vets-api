# frozen_string_literal: true

require 'rails_helper'
require 'pdf_fill/forms/va1010cg'

describe PdfFill::Forms::Va1010cg do
  subject { described_class.new(form_data) }

  describe '#merge_primary_caregiver_has_health_insurance_helper' do
    let(:form_data) do
      {
        'primaryCaregiver' => {
          'hasHealthInsurance' => value
        },
        'helpers' => {
          'primaryCaregiver' => {}
        }
      }
    end

    [
      {
        has_health: false,
        converted: '1'
      },
      {
        has_health: true,
        converted: '2'
      },
      {
        has_health: nil,
        converted: 'Off'
      }
    ].each do |test_data|
      context 'when hasHealthInsurance is false' do
        let(:value) { test_data[:has_health] }

        it 'sets the right value' do
          subject.send(:merge_primary_caregiver_has_health_insurance_helper)
          expect(
            subject.instance_variable_get('@form_data')['helpers']['primaryCaregiver']['hasHealthInsurance']
          ).to eq(test_data[:converted])
        end
      end
    end
  end
end
