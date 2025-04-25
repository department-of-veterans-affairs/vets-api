# frozen_string_literal: true

require 'rails_helper'
require 'veteran_enrollment_system/associations/service'

RSpec.describe VeteranEnrollmentSystem::Associations::Service do
  let(:form) { get_fixture('form1010_ezr/valid_form_with_next_of_kin_and_emergency_contact') }
  let(:update_associations_form) do
    JSON.parse(form.to_json).tap do |f|
      f['veteranContacts'] = build_updated_veteran_contacts
    end
  end
  let(:delete_associations_form) do
    JSON.parse(update_associations_form.to_json).tap do |f|
      f['veteranContacts'] = f['veteranContacts'].map do |contact|
        contact.deep_dup.merge('deleteIndicator' => true)
      end
    end
  end
  let(:missing_required_fields_form) do
    JSON.parse(form.to_json).tap do |f|
      f['veteranContacts'] = build_updated_veteran_contacts.map do |contact|
        contact.except('contactType', 'relationship')
      end
    end
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

  # In the VES Associations API, insert, update, and delete are all handled by the same endpoint
  describe '#update_associations' do
    before do
      allow(Rails.logger).to receive(:info)
      allow(StatsD).to receive(:increment)
    end

    # I wasn't sure if we really needed to test this, but I included it for the sake of ensuring that
    # deleting associations works as expected
    it 'creates associations', run_at: 'Thu, 24 Apr 2025 18:22:00 GMT' do
      # Because the timestamps differ between the cassette's request body and when they are set in the code,
      # the body of the request is not matched in the cassette. We only need the response body to be matched.
      VCR.use_cassette(
        'veteran_enrollment_system/associations/create_associations_success',
        { match_requests_on: %i[method uri], erb: true }
      ) do
        response = described_class.new(current_user, form).update_associations('10-10EZR')

        expect_successful_response_output(response, '2025-04-24T18:22:00Z')
      end
    end

    # I wasn't sure if we really needed to test this, but I included it for the sake of ensuring that
    # deleting associations works as expected
    it 'deletes associations', run_at: 'Thu, 24 Apr 2025 17:08:31 GMT' do
      # Because the timestamps differ between the cassette's request body and when they are set in the code,
      # the body of the request is not matched in the cassette. We only need the response body to be matched.
      VCR.use_cassette(
        'veteran_enrollment_system/associations/delete_associations_success',
        { match_requests_on: %i[method uri], erb: true }
      ) do
        response = described_class.new(current_user, form).update_associations('10-10EZR')

        expect_successful_response_output(response, '2025-04-24T17:08:31Z')
      end
    end

    context 'when a 200 response status is returned' do
      context "when the Associations API code returned is not 'partial_success'" do
        it 'increments StatsD, logs a success message, and returns a success response',
           run_at: 'Thu, 24 Apr 2025 17:08:31 GMT' do
          # Because the timestamps differ between the cassette's request body and when they are set in the code,
          # the body of the request is not matched in the cassette. We only need the response body to be matched.
          VCR.use_cassette(
            'veteran_enrollment_system/associations/update_associations_success',
            { match_requests_on: %i[method uri], erb: true }
          ) do
            response = described_class.new(current_user, form).update_associations('10-10EZR')
            expect_successful_response_output(response, '2025-04-24T17:08:31Z')
          end
        end
      end

      context "when the Associations API code returned is a 'partial_success'" do
        before do
          allow_any_instance_of(described_class).to receive(:reorder_associations).and_return(
            update_associations_form['veteranContacts']
          )
        end

        it 'increments StatsD, logs a partial success message, and returns a partial success response',
           run_at: 'Tue, 22 Apr 2025 22:03:48 GMT' do
          # Because the timestamps differ between the cassette's request body and when they are set in the code,
          # the body of the request is not matched in the cassette. We only need the response body to be matched.
          VCR.use_cassette(
            'veteran_enrollment_system/associations/update_associations_partial_success',
            { match_requests_on: %i[method uri], erb: true }
          ) do
            response = described_class.new(current_user, update_associations_form).update_associations('10-10EZR')

            expect(StatsD).to have_received(:increment).with(
              'api.veteran_enrollment_system.associations.update_associations.partial_success'
            )
            expect(Rails.logger).to have_received(:info).with(
              'The following 10-10EZR associations could not be updated: OTHER_NEXT_OF_KIN, OTHER_EMERGENCY_CONTACT'
            )
            expect(response).to eq(
              {
                status: 'partial_success',
                message: 'Some associations could not be updated',
                timestamp: '2025-04-22T22:03:48Z',
                successful_records: [
                  {
                    role: 'PRIMARY_NEXT_OF_KIN',
                    status: 'DELETED'
                  },
                  {
                    role: 'EMERGENCY_CONTACT',
                    status: 'DELETED'
                  }],
                failed_records: [
                  {
                    role: 'OTHER_NEXT_OF_KIN',
                    status: 'NOT_DELETED_NO_MATCHING_ASSOCIATION'
                  },
                  {
                    role: 'OTHER_EMERGENCY_CONTACT',
                    status: 'NOT_DELETED_NO_MATCHING_ASSOCIATION'
                  }
                ]
              }
            )
          end
        end
      end

      context 'when any status other than 200 is returned' do
        it 'increments StatsD, logs a failure message, and raises an exception', run_at: 'Thu, 24 Apr 2025 19:44:12 GMT' do
          # Because the timestamps differ between the cassette's request body and when they are set in the code,
          # the body of the request is not matched in the cassette. We only need the response body to be matched.
          VCR.use_cassette(
            'veteran_enrollment_system/associations/bad_request',
            { match_requests_on: %i[method uri], erb: true }
          ) do
            failure_message = 
              'associations[0].relationType: Relation type is required, associations[1].role: Role is required, '\
              'associations[0].role: Role is required, associations[3].role: Role is required, associations[2].role: '\
              'Role is required, associations[3].relationType: Relation type is required, associations[2].relationType: '\
              'Relation type is required, associations[1].relationType: Relation type is required'
    
            expect { 
              described_class.new(current_user, delete_associations_form).update_associations('10-10EZR')
             }.to raise_error(
              an_instance_of(Common::Exceptions::BadRequest).and having_attributes(errors: failure_message)
            )
            expect(StatsD).to have_received(:increment).with(
              'api.veteran_enrollment_system.associations.update_associations.failed'
            )
            expect(Rails.logger).to have_received(:info).with(
              "10-10EZR update associations failed: #{failure_message}"
            )
          end
        end
      end
    end
  end

  def build_updated_veteran_contacts
    [
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
  end

  def expect_successful_response_output(response, timestamp)
    expect(StatsD).to have_received(:increment).with(
      'api.veteran_enrollment_system.associations.update_associations.success'
    )
    expect(Rails.logger).to have_received(:info).with('10-10EZR associations updated successfully')
    expect(response).to eq(
      {
        status: 'success',
        message: 'All associations were updated successfully',
        timestamp: timestamp
      }
    )
  end
end
