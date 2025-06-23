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
  let(:associations_with_missing_role_and_name) do
    associations.map do |association|
      association.dup.tap do |dup_association|
        dup_association.delete('role')
        dup_association.delete('name')
        dup_association.delete('relationship')
      end
    end
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
            'contactType' => 'Emergency Contact',
            'fullName' => {
              'first' => 'FIRSTECA',
              'middle' => 'MIDDLEECA',
              'last' => 'LASTECA'
            },
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

    context 'when a VES association is missing the required fields' do
      before do
        allow(Rails.logger).to receive(:error)
      end

      it 'raises an error' do
        expect {
          described_class.new(
            associations_with_missing_role_and_name,
            associations
          ).reconcile_associations
        }.to raise_error(StandardError, "VES association is missing the following field(s): role, name, relationship")
        expect(Rails.logger).to have_received(:error).with("Error transforming VES association: VES association is missing the following field(s): role, name, relationship")
      end
    end
  end
end
