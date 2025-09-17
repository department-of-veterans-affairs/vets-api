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
  let(:associations_missing_relationship_and_name) do
    associations = get_fixture('veteran_enrollment_system/associations/associations_primary_nok_and_ec')
    associations.each do |association|
      association['name'] = nil
      association['relationType'] = nil
      association['role'] = nil
    end
  end

  describe '#reconcile_associations' do
    context 'when associations were deleted on the frontend' do
      it "adds the deleted associations back to the form's associations array with a " \
         "'deleteIndicator' and returns all associations data in the EZR schema format" do
        reconciled_associations = described_class.new(
          get_fixture('veteran_enrollment_system/associations/associations_primary_nok_and_ec'),
          primary_next_of_kin
        ).reconcile_associations

        # 'Emergency Contact' is added back to the associations array
        expect(reconciled_associations.count).to eq(2)
        # The data is in the EZR schema format
        expect(reconciled_associations.find { |a| a['contactType'] == 'Emergency Contact' }).to eq(
          {
            'contactType' => 'Emergency Contact',
            'fullName' => {
              'first' => 'FIRSTECA',
              'middle' => 'MIDDLEECA',
              'last' => 'LASTECA'
            },
            'relationship' => 'BROTHER',
            'deleteIndicator' => true
          }
        )
      end

      context 'when VES associations are missing name, role, and relationship' do
        it 'returns the form associations array with default values' do
          reconciled_associations = described_class.new(
            associations_missing_relationship_and_name,
            primary_next_of_kin
          ).reconcile_associations

          expect(reconciled_associations.count).to eq(3)
          # The data is in the EZR schema format
          expect(reconciled_associations.find { |a| a['contactType'] == described_class::UNKNOWN_ROLE }).to eq(
            {
              'contactType' => described_class::UNKNOWN_ROLE,
              'fullName' => {
                'first' => described_class::UNKNOWN_NAME,
                'last' => described_class::UNKNOWN_NAME
              },
              'relationship' => described_class::UNKNOWN_RELATION,
              'deleteIndicator' => true
            }
          )
        end
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
