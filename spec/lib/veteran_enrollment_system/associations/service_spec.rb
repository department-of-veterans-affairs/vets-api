# frozen_string_literal: true

require 'rails_helper'
require 'veteran_enrollment_system/associations/service'

RSpec.describe VeteranEnrollmentSystem::Associations::Service do
  let(:form) { get_fixture('form1010_ezr/valid_form_with_next_of_kin_and_emergency_contact') }
  let(:updated_associations_form) do
    form.update(
      'veteranContacts' => [
        {
          'fullName' => {
            'first' => 'UpdatedFirstNoKA',
            'middle' => 'UpdatedMiddleNoKA',
            'last' => 'UpdatedLastNoKA',
            'suffix' => 'Jr.'
          },
          'contactType' => 'Primary Next of Kin',
          'relationship' => 'NIECE/NEPHEW',
          'address' => {
            'street' => 'SW 54th St',
            'street2' => 'Apt 1',
            'street3' => 'Unit 4',
            'city' => 'chihuahua',
            'country' => 'MEX',
            'state' => 'chihuahua',
            'provinceCode' => 'chihuahua',
            'postalCode' => '54345'
          },
          'primaryPhone' => '4449131234',
          'alternatePhone' => '6544551234'
        },
        {
          'fullName' => {
            'first' => 'UpdatedFirstNoKB',
            'middle' => 'UpdatedMiddleNoKB',
            'last' => 'UpdatedLastNoKB'
          },
          'contactType' => 'Other Next of Kin',
          'relationship' => 'CHILD-IN-LAW',
          'address' => {
            'street' => '845 Glendale Ave',
            'street2' => 'Unit 43',
            'street3' => '',
            'city' => 'Clearwater',
            'country' => 'USA',
            'state' => 'FL',
            'postalCode' => '33754-8753'
          },
          'primaryPhone' => '1238835546',
          'alternatePhone' => '2658350023'
        },
        {
          'fullName' => {
            'first' => 'UpdatedFirstECA',
            'middle' => 'UpdatedMiddleECA',
            'last' => 'UpdatedLastECA'
          },
          'contactType' => 'Emergency Contact',
          'relationship' => 'EXTENDED FAMILY MEMBER',
          'address' => {
            'street' => '28 Parker St',
            'street2' => '',
            'street3' => '',
            'city' => 'Los Angeles',
            'country' => 'USA',
            'state' => 'CA',
            'postalCode' => '90038-1234'
          },
          'primaryPhone' => '3322743546',
          'alternatePhone' => '2694437134'
        },
        {
          'fullName' => {
            'first' => 'UpdatedFirstECB',
            'middle' => 'UpdatedMiddleECB',
            'last' => 'UpdatedLastECB'
          },
          'contactType' => 'Other emergency contact',
          'relationship' => 'GRANDCHILD',
          'address' => {
            'street' => '875 West Blvd',
            'street2' => 'Apt 3',
            'street3' => 'Unit 6',
            'city' => 'Wichita',
            'country' => 'USA',
            'state' => 'KS',
            'postalCode' => '67203-1234'
          },
          'primaryPhone' => '9942738265',
          'alternatePhone' => '9563001117'
        }
      ]
    )
  end
  let(:deleted_associations_form) do
    updated_associations_form.update(
      'veteranContacts' => updated_associations_form['veteranContacts'].map { |a| a.update('deleteIndicator' => true) }
    )
  end
  let(:current_user) do
    create(
      :evss_user,
      :loa3,
      icn: '1012829228V424035',
      birth_date: '1963-07-05',
      first_name: 'FirstName',
      middle_name: 'MiddleName',
      last_name: 'ZZTEST',
      suffix: 'Jr.',
      ssn: '111111234',
      gender: 'F'
    )
  end
  let(:service) { described_class.new(current_user, form) }

  describe '#update_associations' do
    context 'when a 200 response status is returned' do
      context "when the code returned is not 'completed_success'" do
        it 'updates the associations', run_at: 'Tue, 22 Apr 2025 22:03:48 GMT' do
          VCR.use_cassette(
            'veteran_enrollment_system/associations/example4',
            { match_requests_on: %i[method uri body], erb: true }
          ) do
            response = service.update_associations(form)

            expect(response).
          end
        end
      end
    end
  end
end

it "returns an object that includes 'success', 'formSubmissionId', and 'timestamp'",
           run_at: 'Tue, 22 Apr 2025 22:03:48 GMT' do
          VCR.use_cassette(
            'veteran_enrollment_system/associations/example4',
            { match_requests_on: %i[method uri body], erb: true }
          ) do
