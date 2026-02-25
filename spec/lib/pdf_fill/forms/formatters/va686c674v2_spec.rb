# frozen_string_literal: true

require 'rails_helper'
require 'pdf_fill/forms/formatters/va686c674v2'

RSpec.describe PdfFill::Forms::Formatters::Va686c674v2 do
  describe '.expand_no_ssn_cases' do
    let(:form_data) do
      {
        'dependents_application' => {
          'spouse_information' => {},
          'children_to_add' => []
        }
      }
    end

    context 'when spouse has no SSN' do
      before do
        form_data['dependents_application']['spouse_information'] = {
          'no_ssn' => true,
          'no_ssn_reason' => 'Does not have SSN'
        }
      end

      it 'replaces spouse SSN with placeholder text' do
        described_class.expand_no_ssn_cases(form_data)

        spouse_ssn = form_data['dependents_application']['spouse_information']['ssn']
        expect(spouse_ssn['first']).to eq('See')
        expect(spouse_ssn['second']).to eq('ad')
        expect(spouse_ssn['third']).to eq("d'l ")
      end

      it 'adds spouse no SSN reason to remarks' do
        described_class.expand_no_ssn_cases(form_data)

        # Combine all remark lines to check for the full text
        combined_remarks = form_data['remarks'].values.compact.join
        expect(combined_remarks).to include('11C. Spouse no SSN reason: Does not have SSN')
      end
    end

    context 'when spouse has no SSN but no reason provided' do
      before do
        form_data['dependents_application']['spouse_information'] = {
          'no_ssn' => true
        }
      end

      it 'replaces spouse SSN with placeholder text' do
        described_class.expand_no_ssn_cases(form_data)

        spouse_ssn = form_data['dependents_application']['spouse_information']['ssn']
        expect(spouse_ssn['first']).to eq('See')
        expect(spouse_ssn['second']).to eq('ad')
        expect(spouse_ssn['third']).to eq("d'l ")
      end

      it 'does not add remarks when no reason is provided' do
        described_class.expand_no_ssn_cases(form_data)

        expect(form_data['remarks']).to be_nil
      end
    end

    context 'when spouse has specific valid no_ssn_reason values' do
      ['Nonresident Alien', 'No SSN Assigned by SSA'].each do |valid_reason|
        context "with reason '#{valid_reason}'" do
          before do
            form_data['dependents_application']['spouse_information'] = {
              'no_ssn' => true,
              'no_ssn_reason' => valid_reason
            }
          end

          it 'processes the valid reason correctly' do
            described_class.expand_no_ssn_cases(form_data)

            combined_remarks = form_data['remarks'].values.compact.join
            expect(combined_remarks).to include("11C. Spouse no SSN reason: #{valid_reason}")
          end
        end
      end
    end

    context 'when children have no SSN' do
      before do
        form_data['dependents_application']['children_to_add'] = [
          {
            'no_ssn_reason' => 'Nonresident Alien',
            'no_ssn' => true
          },
          {
            'no_ssn_reason' => 'No SSN Assigned by SSA',
            'no_ssn' => true
          }
        ]
      end

      it 'replaces children SSN with placeholder text' do
        described_class.expand_no_ssn_cases(form_data)

        first_child_ssn = form_data['dependents_application']['children_to_add'][0]['ssn']
        expect(first_child_ssn['first']).to eq('See')
        expect(first_child_ssn['second']).to eq('ad')
        expect(first_child_ssn['third']).to eq("d'l ")

        second_child_ssn = form_data['dependents_application']['children_to_add'][1]['ssn']
        expect(second_child_ssn['first']).to eq('See')
        expect(second_child_ssn['second']).to eq('ad')
        expect(second_child_ssn['third']).to eq("d'l ")
      end

      it 'adds children no SSN reasons to remarks with correct question numbers' do
        described_class.expand_no_ssn_cases(form_data)

        # Combine all remark lines to check for the full text
        combined_remarks = form_data['remarks'].values.compact.join
        expect(combined_remarks).to include('16B. Child no SSN reason: Nonresident Alien')
        expect(combined_remarks).to include('17B. Child no SSN reason: No SSN Assigned by SSA')
      end

      context 'when there are more than 4 children' do
        before do
          form_data['dependents_application']['children_to_add'] = [
            { 'no_ssn_reason' => 'Nonresident Alien', 'no_ssn' => true },
            { 'no_ssn_reason' => 'No SSN Assigned by SSA', 'no_ssn' => true },
            { 'no_ssn_reason' => 'Nonresident Alien', 'no_ssn' => true },
            { 'no_ssn_reason' => 'Nonresident Alien', 'no_ssn' => true },
            { 'no_ssn_reason' => 'Nonresident Alien', 'no_ssn' => true },
            { 'no_ssn_reason' => 'Nonresident Alien', 'no_ssn' => true }
          ]
        end

        it 'uses correct question numbers for children beyond the first 4' do
          described_class.expand_no_ssn_cases(form_data)

          # Combine all remark lines to check for the full text
          combined_remarks = form_data['remarks'].values.compact.join
          expect(combined_remarks).to include('16B. Child no SSN reason: Nonresident Alien')
          expect(combined_remarks).to include('17B. Child no SSN reason: No SSN Assigned by SSA')
          expect(combined_remarks).to include('18B. Child no SSN reason: Nonresident Alien')
          expect(combined_remarks).to include('19B. Child no SSN reason: Nonresident Alien')
          expect(combined_remarks).to include('1B. Child no SSN reason: Nonresident Alien')
          expect(combined_remarks).to include('2B. Child no SSN reason: Nonresident Alien')
        end
      end
    end

    context 'when both spouse and children have no SSN' do
      before do
        form_data['dependents_application']['spouse_information'] = {
          'no_ssn' => true,
          'no_ssn_reason' => 'Nonresident Alien'
        }
        form_data['dependents_application']['children_to_add'] = [
          {
            'no_ssn_reason' => 'Nonresident Alien',
            'no_ssn' => true
          }
        ]
      end

      it 'combines all reasons in remarks' do
        described_class.expand_no_ssn_cases(form_data)

        # Combine all remark lines to check for the full text
        combined_remarks = form_data['remarks'].values.compact.join
        expect(combined_remarks).to include('11C. Spouse no SSN reason: Nonresident Alien')
        expect(combined_remarks).to include('16B. Child no SSN reason: Nonresident Alien')
      end
    end

    context 'when remarks exceed 35 character limit' do
      before do
        form_data['dependents_application']['spouse_information'] = {
          'no_ssn' => true,
          'no_ssn_reason' => 'Very long reason that will definitely exceed the character limit for a single line'
        }
      end

      it 'splits remarks into multiple lines' do
        described_class.expand_no_ssn_cases(form_data)

        expect(form_data['remarks']['remarks_line1']).to be_present
        expect(form_data['remarks']['remarks_line1'].length).to be <= 35
        expect(form_data['remarks']['remarks_line2']).to be_present
        expect(form_data['remarks']['remarks_line3']).to be_present
      end
    end

    context 'when no one has no SSN' do
      it 'does not modify form data' do
        original_form_data = form_data.deep_dup
        described_class.expand_no_ssn_cases(form_data)

        expect(form_data).to eq(original_form_data)
      end
    end

    context 'when spouse_information is nil' do
      before do
        form_data['dependents_application']['spouse_information'] = nil
      end

      it 'does not raise an error' do
        expect { described_class.expand_no_ssn_cases(form_data) }.not_to raise_error
      end
    end

    context 'when children_to_add is nil' do
      before do
        form_data['dependents_application']['children_to_add'] = nil
      end

      it 'does not raise an error' do
        expect { described_class.expand_no_ssn_cases(form_data) }.not_to raise_error
      end
    end

    context 'when children have no_ssn flag set' do
      before do
        form_data['dependents_application']['children_to_add'] = [
          {
            'no_ssn' => true,
            'no_ssn_reason' => 'Nonresident Alien'
          },
          {
            'no_ssn' => true,
            'no_ssn_reason' => 'No SSN Assigned by SSA'
          }
        ]
      end

      it 'replaces children SSN with placeholder text' do
        described_class.expand_no_ssn_cases(form_data)

        first_child_ssn = form_data['dependents_application']['children_to_add'][0]['ssn']
        expect(first_child_ssn['first']).to eq('See')
        expect(first_child_ssn['second']).to eq('ad')
        expect(first_child_ssn['third']).to eq("d'l ")

        second_child_ssn = form_data['dependents_application']['children_to_add'][1]['ssn']
        expect(second_child_ssn['first']).to eq('See')
        expect(second_child_ssn['second']).to eq('ad')
        expect(second_child_ssn['third']).to eq("d'l ")
      end

      it 'adds children no SSN reasons to remarks with correct question numbers' do
        described_class.expand_no_ssn_cases(form_data)

        combined_remarks = form_data['remarks'].values.compact.join
        expect(combined_remarks).to include('16B. Child no SSN reason: Nonresident Alien')
        expect(combined_remarks).to include('17B. Child no SSN reason: No SSN Assigned by SSA')
      end
    end

    context 'when children have no_ssn flag but no reason' do
      before do
        form_data['dependents_application']['children_to_add'] = [
          {
            'no_ssn' => true
          }
        ]
      end

      it 'replaces child SSN with placeholder text' do
        described_class.expand_no_ssn_cases(form_data)

        first_child_ssn = form_data['dependents_application']['children_to_add'][0]['ssn']
        expect(first_child_ssn['first']).to eq('See')
        expect(first_child_ssn['second']).to eq('ad')
        expect(first_child_ssn['third']).to eq("d'l ")
      end

      it 'does not add remarks when no reason is provided' do
        described_class.expand_no_ssn_cases(form_data)

        expect(form_data['remarks']).to be_nil
      end
    end

    context 'when children are mixed with and without no_ssn flags and reasons' do
      before do
        form_data['dependents_application']['children_to_add'] = [
          {
            'ssn' => '111111111'
            # No no_ssn flag or reason - should be untouched
          },
          {
            'no_ssn_reason' => 'Nonresident Alien'
          },
          {
            'no_ssn' => true
            # Has no_ssn flag but no reason
          },
          {
            'no_ssn' => true,
            'no_ssn_reason' => 'No SSN Assigned by SSA'
            # Has both flag and reason
          }
        ]
      end

      it 'processes only children with no_ssn flags or reasons' do
        described_class.expand_no_ssn_cases(form_data)

        # First child (index 0) should remain unchanged
        expect(form_data['dependents_application']['children_to_add'][0]['ssn']).to eq('111111111')

        # Second child (index 1) should have placeholder SSN due to no_ssn_reason
        second_child_ssn = form_data['dependents_application']['children_to_add'][1]['ssn']
        expect(second_child_ssn['first']).to eq('See')

        # Third child (index 2) should have placeholder SSN due to no_ssn flag
        third_child_ssn = form_data['dependents_application']['children_to_add'][2]['ssn']
        expect(third_child_ssn['first']).to eq('See')

        # Fourth child (index 3) should have placeholder SSN
        fourth_child_ssn = form_data['dependents_application']['children_to_add'][3]['ssn']
        expect(fourth_child_ssn['first']).to eq('See')
      end

      it 'adds remarks only for children with no_ssn_reason' do
        described_class.expand_no_ssn_cases(form_data)

        combined_remarks = form_data['remarks'].values.compact.join
        expect(combined_remarks).to include('17B. Child no SSN reason: Nonresident Alien')
        expect(combined_remarks).to include('19B. Child no SSN reason: No SSN Assigned by SSA')
        expect(combined_remarks).not_to include('16B') # First child has no reason
        expect(combined_remarks).not_to include('18B') # Third child has no reason
      end
    end

    context 'edge case: question number calculation with gaps' do
      before do
        # Test with 8 children where some have no SSN and some don't
        # This tests the transition from question 19 to 1
        form_data['dependents_application']['children_to_add'] = Array.new(8) do |i|
          if [1, 3, 4, 6, 7].include?(i)
            {
              'no_ssn_reason' => "Child #{i + 1}",
              'no_ssn' => true
            }
          else
            {
              'ssn' => "#{i}#{i}#{i}#{i}#{i}#{i}#{i}#{i}#{i}"
            }
          end
        end
      end

      it 'correctly calculates question numbers including the 19 to 1 transition' do
        described_class.expand_no_ssn_cases(form_data)

        combined_remarks = form_data['remarks'].values.compact.join
        expect(combined_remarks).to include('17B. Child no SSN reason: Child 2')  # index 1 -> question 17
        expect(combined_remarks).to include('19B. Child no SSN reason: Child 4')  # index 3 -> question 19
        expect(combined_remarks).to include('1B. Child no SSN reason: Child 5')   # index 4 -> question 1
        expect(combined_remarks).to include('3B. Child no SSN reason: Child 7')   # index 6 -> question 3
        expect(combined_remarks).to include('4B. Child no SSN reason: Child 8')   # index 7 -> question 4
      end
    end

    context 'valid no_ssn_reason values for children' do
      ['Nonresident Alien', 'No SSN Assigned by SSA'].each do |valid_reason|
        context "with reason '#{valid_reason}'" do
          before do
            form_data['dependents_application']['children_to_add'] = [
              {
                'no_ssn' => true,
                'no_ssn_reason' => valid_reason
              }
            ]
          end

          it 'processes the valid reason correctly' do
            described_class.expand_no_ssn_cases(form_data)

            combined_remarks = form_data['remarks'].values.compact.join
            expect(combined_remarks).to include("16B. Child no SSN reason: #{valid_reason}")
          end
        end
      end
    end
  end

  describe '.calculate_child_question_number' do
    it 'calculates correct question numbers for first 4 children' do
      expect(described_class.calculate_child_question_number(0)).to eq(16)
      expect(described_class.calculate_child_question_number(1)).to eq(17)
      expect(described_class.calculate_child_question_number(2)).to eq(18)
      expect(described_class.calculate_child_question_number(3)).to eq(19)
    end

    it 'calculates correct question numbers for children beyond first 4' do
      expect(described_class.calculate_child_question_number(4)).to eq(1)
      expect(described_class.calculate_child_question_number(5)).to eq(2)
      expect(described_class.calculate_child_question_number(6)).to eq(3)
      expect(described_class.calculate_child_question_number(7)).to eq(4)
    end

    it 'handles large indices correctly' do
      expect(described_class.calculate_child_question_number(10)).to eq(7)
      expect(described_class.calculate_child_question_number(15)).to eq(12)
    end
  end
end
