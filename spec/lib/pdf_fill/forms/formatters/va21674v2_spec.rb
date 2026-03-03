# frozen_string_literal: true

require 'rails_helper'
require 'pdf_fill/forms/formatters/va21674v2'

RSpec.describe PdfFill::Forms::Formatters::Va21674v2 do
  describe '.expand_no_ssn_cases' do
    let(:form_data) do
      {
        'dependents_application' => {
          'student_information' => [
            {}
          ]
        }
      }
    end

    context 'when student has no SSN' do
      before do
        form_data['dependents_application']['student_information'][0] = {
          'no_ssn' => true,
          'no_ssn_reason' => 'Nonresident Alien'
        }
      end

      it 'replaces student SSN with placeholder text' do
        described_class.expand_no_ssn_cases(form_data)

        student_ssn = form_data['dependents_application']['student_information'][0]['ssn']
        expect(student_ssn['first']).to eq('See')
        expect(student_ssn['second']).to eq('ad')
        expect(student_ssn['third']).to eq("d'l ")
      end

      it 'adds student no SSN reason to remarks' do
        described_class.expand_no_ssn_cases(form_data)

        remarks = form_data['dependents_application']['student_information'][0]['remarks']
        expect(remarks).to eq('5. Student no SSN reason: Nonresident Alien')
      end
    end

    context 'when student has no SSN but no reason provided' do
      before do
        form_data['dependents_application']['student_information'][0] = {
          'no_ssn' => true
        }
      end

      it 'replaces student SSN with placeholder text' do
        described_class.expand_no_ssn_cases(form_data)

        student_ssn = form_data['dependents_application']['student_information'][0]['ssn']
        expect(student_ssn['first']).to eq('See')
        expect(student_ssn['second']).to eq('ad')
        expect(student_ssn['third']).to eq("d'l ")
      end

      it 'does not add remarks when no reason is provided' do
        described_class.expand_no_ssn_cases(form_data)

        remarks = form_data['dependents_application']['student_information'][0]['remarks']
        expect(remarks).to be_nil
      end
    end

    context 'when student has specific valid no_ssn_reason values' do
      ['Nonresident Alien', 'No SSN Assigned by SSA'].each do |valid_reason|
        context "with reason '#{valid_reason}'" do
          before do
            form_data['dependents_application']['student_information'][0] = {
              'no_ssn' => true,
              'no_ssn_reason' => valid_reason
            }
          end

          it 'processes the valid reason correctly' do
            described_class.expand_no_ssn_cases(form_data)

            remarks = form_data['dependents_application']['student_information'][0]['remarks']
            expect(remarks).to eq("5. Student no SSN reason: #{valid_reason}")
          end
        end
      end
    end

    context 'when student has SSN' do
      before do
        form_data['dependents_application']['student_information'][0] = {
          'no_ssn' => false,
          'ssn' => '123456789'
        }
      end

      it 'does not modify student SSN' do
        original_ssn = form_data['dependents_application']['student_information'][0]['ssn']
        described_class.expand_no_ssn_cases(form_data)

        expect(form_data['dependents_application']['student_information'][0]['ssn']).to eq(original_ssn)
      end

      it 'does not add remarks' do
        described_class.expand_no_ssn_cases(form_data)

        expect(form_data['dependents_application']['student_information'][0]['remarks']).to be_nil
      end
    end

    context 'when no_ssn is nil' do
      before do
        form_data['dependents_application']['student_information'][0] = {
          'no_ssn' => nil,
          'ssn' => '123456789'
        }
      end

      it 'does not modify form data' do
        original_form_data = form_data.deep_dup
        described_class.expand_no_ssn_cases(form_data)

        expect(form_data).to eq(original_form_data)
      end
    end

    context 'when student_information is empty' do
      before do
        form_data['dependents_application']['student_information'] = []
      end

      it 'does not raise an error' do
        expect { described_class.expand_no_ssn_cases(form_data) }.not_to raise_error
      end
    end

    context 'when student_information is nil' do
      before do
        form_data['dependents_application']['student_information'] = nil
      end

      it 'does not raise an error' do
        expect { described_class.expand_no_ssn_cases(form_data) }.not_to raise_error
      end
    end
  end

  describe '.expand_phone_number' do
    it 'formats a 10-digit phone number string' do
      result = described_class.expand_phone_number('1234567890')

      expect(result).to eq({
                             'phone_area_code' => '123',
                             'phone_first_three_numbers' => '456',
                             'phone_last_four_numbers' => '7890'
                           })
    end

    it 'formats a phone number with special characters' do
      result = described_class.expand_phone_number('(123) 456-7890')

      expect(result).to eq({
                             'phone_area_code' => '123',
                             'phone_first_three_numbers' => '456',
                             'phone_last_four_numbers' => '7890'
                           })
    end

    it 'handles integer input' do
      result = described_class.expand_phone_number(1_234_567_890)

      expect(result).to eq({
                             'phone_area_code' => '123',
                             'phone_first_three_numbers' => '456',
                             'phone_last_four_numbers' => '7890'
                           })
    end

    it 'handles short phone numbers gracefully' do
      result = described_class.expand_phone_number('123')

      expect(result).to eq({
                             'phone_area_code' => '123',
                             'phone_first_three_numbers' => '',
                             'phone_last_four_numbers' => ''
                           })
    end
  end

  describe '.get_program' do
    it 'returns nil for blank input' do
      expect(described_class.get_program(nil)).to be_nil
      expect(described_class.get_program({})).to be_nil
    end

    it 'maps program types correctly' do
      programs = {
        'ch35' => true,
        'fry' => true
      }

      result = described_class.get_program(programs)
      expect(result).to eq('Chapter 35, Fry Scholarship')
    end

    it 'handles single program' do
      programs = { 'feca' => true }

      result = described_class.get_program(programs)
      expect(result).to eq('FECA')
    end

    it 'filters out false values' do
      programs = {
        'ch35' => true,
        'fry' => false,
        'feca' => true,
        'other' => false
      }

      result = described_class.get_program(programs)
      expect(result).to eq('Chapter 35, FECA')
    end
  end

  describe 'checkbox and radio button helpers' do
    describe '.select_checkbox' do
      it 'returns "On" for true values' do
        expect(described_class.select_checkbox(true)).to eq('On')
      end

      it 'returns nil for false values' do
        expect(described_class.select_checkbox(false)).to be_nil
      end
    end

    describe '.select_radio_button' do
      it 'returns 0 for true values' do
        expect(described_class.select_radio_button(true)).to eq(0)
      end

      it 'returns nil for false values' do
        expect(described_class.select_radio_button(false)).to be_nil
      end
    end
  end
end
