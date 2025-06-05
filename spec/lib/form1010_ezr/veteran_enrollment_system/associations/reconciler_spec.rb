# frozen_string_literal: true

require 'rails_helper'
require 'form1010_ezr/veteran_enrollment_system/associations/reconciler'

RSpec.describe Form1010Ezr::VeteranEnrollmentSystem::Associations::Reconciler do
  let(:associations) do
    fixture = get_fixture('form1010_ezr/valid_form_with_next_of_kin_and_emergency_contact')
    fixture['nextOfKins'].concat(fixture['emergencyContacts'])
  end
  let(:primary_next_of_kin) do
    associations.select { |association| association['contactType'] == 'Primary Next of Kin' }
  end

  describe '#reconcile_associations' do
    context 'when associations were deleted on the frontend' do
      it "adds the deleted associations back to the form's associations array with a " \
         "'deleteIndicator' and returns all associations data in the VES format" do
        reconciled_associations = described_class.new(
          get_fixture('veteran_enrollment_system/associations/associations_primary_nok_and_ec'),
          primary_next_of_kin
        ).reconcile_associations

        # 'Emergency Contact' is added back to the associations array
        expect(reconciled_associations.count).to eq(2)
        # The data is in the VES format
        expect(reconciled_associations.find { |a| a['contactType'] == 'Emergency Contact' }).to eq(
          {
            'address' => {
              'street' => '123 NW 5th St',
              'street2' => 'Apt 5',
              'street3' => 'Unit 6',
              'city' => 'durango',
              'country' => 'MEX',
              'postalCode' => '21231'
            },
            'alternatePhone' => '2699352134',
            'contactType' => 'Emergency Contact',
            'fullName' => {
              'first' => 'FIRSTECA',
              'middle' => 'MIDDLEECA',
              'last' => 'LASTECA'
            },
            'primaryPhone' => '7452743546',
            'relationship' => 'BROTHER',
            'deleteIndicator' => true
          }
        )
      end
    end

    context 'when no associations were deleted on the frontend' do
      it 'returns the form associations array unchanged' do
        reconciled_associations = described_class.new(
          get_fixture('veteran_enrollment_system/associations/associations_maximum'),
          associations
        ).reconcile_associations

        expect(reconciled_associations).to eq(associations)
      end
    end
  end
end