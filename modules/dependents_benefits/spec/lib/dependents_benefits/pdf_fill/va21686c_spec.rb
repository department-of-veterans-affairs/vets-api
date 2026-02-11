# frozen_string_literal: true

require 'rails_helper'
require 'dependents_benefits/pdf_fill/va21686c'

RSpec.describe DependentsBenefits::PdfFill::Va21686c do
  let(:form_data) do
    {
      'veteran_information' => {
        'full_name' => {
          'first' => 'John',
          'middle' => 'M',
          'last' => 'Doe'
        },
        'ssn' => '123456789',
        'birth_date' => '1980-01-01'
      },
      'dependents_application' => {}
    }
  end

  let(:va21686c) { described_class.new(form_data) }

  describe '#merge_stepchildren_helpers' do
    context 'when stepchild address is present' do
      before do
        form_data['dependents_application']['step_children'] = [
          {
            'full_name' => {
              'first' => 'Billy',
              'middle' => 'Yohan',
              'last' => 'Johnson'
            },
            'who_does_the_stepchild_live_with' => {
              'first' => 'Bob',
              'middle' => 'B',
              'last' => 'Smith'
            },
            'address' => {
              'street' => '456 Main St',
              'city' => 'Test City',
              'state' => 'CA',
              'postal_code' => '12345',
              'country' => 'USA'
            },
            'living_expenses_paid' => 'More than half'
          }
        ]
      end

      it 'processes stepchildren without error' do
        expect { va21686c.send(:merge_stepchildren_helpers) }.not_to raise_error
      end

      it 'processes address fields when present' do
        va21686c.send(:merge_stepchildren_helpers)
        stepchild = va21686c.form_data['dependents_application']['step_children'][0]

        expect(stepchild['address']).to be_present
      end
    end

    context 'when stepchild address is not present' do
      before do
        # Based on real-world data where address field may be missing
        form_data['dependents_application']['step_children'] = [
          {
            'full_name' => {
              'first' => 'Jane',
              'last' => 'Smith'
            },
            'ssn' => '987654321',
            'birth_date' => '2000-01-01'
          }
        ]
      end

      it 'does not raise an error when address is missing' do
        expect { va21686c.send(:merge_stepchildren_helpers) }.not_to raise_error
      end

      it 'does not attempt to process postal_code when address is missing' do
        va21686c.send(:merge_stepchildren_helpers)
        stepchild = va21686c.form_data['dependents_application']['step_children'][0]

        # Address should remain nil/absent
        expect(stepchild['address']).to be_nil
      end

      it 'still processes other stepchild fields' do
        va21686c.send(:merge_stepchildren_helpers)
        stepchild = va21686c.form_data['dependents_application']['step_children'][0]

        # The full_name should still be present
        expect(stepchild['full_name']).to be_present
      end
    end

    context 'when step_children is blank' do
      before do
        form_data['dependents_application']['step_children'] = nil
      end

      it 'returns early without error' do
        expect { va21686c.send(:merge_stepchildren_helpers) }.not_to raise_error
      end
    end

    context 'when step_children is empty array' do
      before do
        form_data['dependents_application']['step_children'] = []
      end

      it 'returns early without error' do
        expect { va21686c.send(:merge_stepchildren_helpers) }.not_to raise_error
      end
    end

    context 'when stepchild has minimal data' do
      before do
        # Anonymized version of actual failing data
        form_data['veteran_information'] = {
          'full_name' => {
            'first' => 'Test',
            'middle' => 'T',
            'last' => 'Veteran'
          }
        }
        form_data['dependents_application'] = {
          'veteran_contact_information' => {
            'phone_number' => '5551234567',
            'email_address' => 'test@example.com',
            'veteran_address' => {
              'country' => 'USA',
              'street' => '123 Test St',
              'city' => 'Test City',
              'state' => 'CA',
              'postal_code' => '12345'
            }
          },
          'step_children' => [
            {
              'full_name' => {
                'first' => 'Test',
                'last' => 'Child'
              },
              'ssn' => '987654321',
              'birth_date' => '2000-01-01'
              # NOTE: no 'address', no 'living_expenses_paid', no 'who_does_the_stepchild_live_with'
            }
          ]
        }
      end

      it 'processes successfully without address field' do
        expect { va21686c.send(:merge_stepchildren_helpers) }.not_to raise_error
      end

      it 'does not crash on missing optional fields' do
        va21686c.send(:merge_stepchildren_helpers)
        stepchild = va21686c.form_data['dependents_application']['step_children'][0]

        # Should have processed without errors
        expect(stepchild).to be_present
        expect(stepchild['full_name']).to be_present
        expect(stepchild['address']).to be_nil
      end
    end
  end

  describe '#merge_divorce_helpers' do
    context 'when divorce information is present' do
      before do
        form_data['dependents_application']['report_divorce'] = {
          'date' => '2010-05-15',
          'full_name' => {
            'first' => 'Jane',
            'middle' => 'A',
            'last' => 'Doe'
          },
          'divorce_location' => {
            'city' => 'Fictional City',
            'state' => 'NY',
            'country' => 'USA'
          }
        }
      end

      it 'processes divorces without error' do
        expect { va21686c.send(:merge_divorce_helpers) }.not_to raise_error
      end

      it 'processes divorce data correctly' do
        va21686c.send(:merge_divorce_helpers)
        divorce_data = va21686c.form_data['dependents_application']['report_divorce']

        expect(divorce_data['date']).to be_a(Hash)
        expect(divorce_data['date']['month']).to eq('05')
        expect(divorce_data['date']['day']).to eq('15')
        expect(divorce_data['date']['year']).to eq('2010')
        expect(divorce_data['full_name']['first']).to eq('Jane')
        expect(divorce_data['full_name']['middleInitial']).to eq('A')
        expect(divorce_data['full_name']['last']).to eq('Doe')
        expect(divorce_data['divorce_location']['country']).to eq('US')
      end
    end

    context 'when divorce information is absent' do
      before do
        form_data['dependents_application']['report_divorce'] = nil
      end

      it 'returns early without error' do
        expect { va21686c.send(:merge_divorce_helpers) }.not_to raise_error
        expect(va21686c.form_data['dependents_application']['report_divorce']).to be_nil
      end
    end

    context 'when divorce location country is not present' do
      before do
        form_data['dependents_application']['report_divorce'] = {
          'date' => '2010-05-15',
          'full_name' => {
            'first' => 'Jane',
            'last' => 'Doe'
          },
          'divorce_location' => {
            'city' => 'Fictional City',
            'state' => 'NY'
          }
        }
      end

      it 'processes without error when country is missing' do
        expect { va21686c.send(:merge_divorce_helpers) }.not_to raise_error
      end
    end
  end
end
