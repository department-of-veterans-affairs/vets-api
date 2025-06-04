# frozen_string_literal: true

require 'rails_helper'
require 'veteran_enrollment_system/associations/service'

RSpec.describe VeteranEnrollmentSystem::Associations::Service do
  let(:associations_maximum) do
    get_fixture('veteran_enrollment_system/associations/associations_maximum')
  end
  let(:associations_maximum_incorrectly_ordered) do
    get_fixture('veteran_enrollment_system/associations/associations_maximum_incorrectly_ordered')
  end

  let(:updated_associations) do
    [
      {
        'name' => {
          'givenName' => 'UPDATEDFIRSTNOKA',
          'middleName' => 'UPDATEDMIDDLENOKA',
          'familyName' => 'UPDATEDLASTNOKA',
          'suffix' => 'JR.'
        },
        'role' => 'PRIMARY_NEXT_OF_KIN',
        'relationType' => 'NIECE_NEPHEW',
        'address' => {
          'line1' => 'SW 54th St',
          'line2' => 'Apt 1',
          'line3' => 'Unit 4',
          'city' => 'chihuahua',
          'country' => 'MEX',
          'provinceCode' => 'chihuahua',
          'postalCode' => '54345'
        },
        'primaryPhone' => '4449131234',
        'alternatePhone' => '6544551234'
      },
      {
        'name' => {
          'givenName' => 'UPDATEDFIRSTNOKB',
          'middleName' => 'UPDATEDMIDDLENOKB',
          'familyName' => 'UPDATEDLASTNOKB'
        },
        'role' => 'OTHER_NEXT_OF_KIN',
        'relationType' => 'CHILDINLAW',
        'address' => {
          'line1' => '845 Glendale Ave',
          'line2' => 'Unit 43',
          'city' => 'Clearwater',
          'country' => 'USA',
          'state' => 'FL',
          'zipCode' => '33754',
          'zipPlus4' => '8753'
        },
        'primaryPhone' => '1238835546',
        'alternatePhone' => '2658350023'
      },
      {
        'name' => {
          'givenName' => 'UPDATEDFIRSTECA',
          'middleName' => 'UPDATEDMIDDLEECA',
          'familyName' => 'UPDATEDLASTECA'
        },
        'role' => 'EMERGENCY_CONTACT',
        'relationType' => 'EXTENDED_FAMILY_MEMBER',
        'address' => {
          'line1' => '28 Parker St',
          'city' => 'Los Angeles',
          'country' => 'USA',
          'state' => 'CA',
          'zipCode' => '90038',
          'zipPlus4' => '1234'
        },
        'primaryPhone' => '3322743546',
        'alternatePhone' => '2694437134'
      },
      {
        'name' => {
          'givenName' => 'UPDATEDFIRSTECB',
          'middleName' => 'UPDATEDMIDDLEECB',
          'familyName' => 'UPDATEDLASTECB'
        },
        'role' => 'OTHER_EMERGENCY_CONTACT',
        'relationType' => 'GRANDCHILD',
        'address' => {
          'line1' => '875 West Blvd',
          'line2' => 'Apt 3',
          'line3' => 'Unit 6',
          'city' => 'Wichita',
          'country' => 'USA',
          'state' => 'KS',
          'zipCode' => '67203',
          'zipPlus4' => '1234'
        },
        'primaryPhone' => '9942738265',
        'alternatePhone' => '9563001117'
      }
    ]
  end
  let(:delete_associations) do
    JSON.parse(updated_associations.to_json).map do |association|
      association.merge('deleteIndicator' => true)
    end
  end
  let(:missing_required_fields) do
    JSON.parse(updated_associations.to_json).map do |association|
      association['relationType'] = ''
      association['role'] = ''
      association
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
  let(:current_user_with_invalid_icn) do
    create(
      :evss_user,
      :loa3,
      icn: '1012829228V42403'
    )
  end

  describe '#get_associations' do
    before do
      allow(Rails.logger).to receive(:info)
      allow(Rails.logger).to receive(:error)
      allow(StatsD).to receive(:increment)
    end

    context 'when a 200 response status is returned' do
      it 'returns an array of associations', run_at: 'Thu, 01 May 2025 17:03:17 GMT' do
        VCR.use_cassette(
          'veteran_enrollment_system/associations/get_associations_maximum',
          { match_requests_on: %i[method uri body], erb: true }
        ) do
          response = described_class.new(current_user).get_associations('10-10EZR')

          expect(response).to be_a(Array)
          expect(response).to eq(
            get_fixture('veteran_enrollment_system/associations/associations_maximum')
          )
        end
      end
    end

    context 'when any status other than 200 is returned' do
      it 'increments StatsD, logs a failure message, and raises an exception',
         run_at: 'Thu, 01 May 2025 17:06:05 GMT' do
        VCR.use_cassette(
          'veteran_enrollment_system/associations/get_associations_error',
          { match_requests_on: %i[method uri body], erb: true }
        ) do
          failure_message = 'No record found for a person with the specified ICN'

          expect do
            described_class.new(current_user_with_invalid_icn).get_associations('10-10EZR')
          end.to raise_error(
            an_instance_of(Common::Exceptions::ResourceNotFound)
          )
          expect(StatsD).to have_received(:increment).with(
            'api.veteran_enrollment_system.associations.get_associations.failed'
          )
          expect(Rails.logger).to have_received(:error).with(
            "10-10EZR retrieve associations failed: #{failure_message}"
          )
        end
      end
    end
  end

  # In the VES Associations API, insert, update, and delete are all handled by the same endpoint
  describe '#update_associations' do
    before do
      allow(Rails.logger).to receive(:info)
      allow(Rails.logger).to receive(:error)
      allow(StatsD).to receive(:increment)
      # Because the 'lastUpdateDate' timestamps differ between the cassette's request body and when
      # they are set in the code, we'll ignore them when matching the request bodies.
      VCR.configure do |config|
        config.register_request_matcher :body_ignoring_last_update_date do |r1, r2|
          body1 = JSON.parse(r1.body)
          body2 = JSON.parse(r2.body)

          # Strip lastUpdateDate from each association
          associations1 = body1['associations'] || []
          associations2 = body2['associations'] || []

          associations1.each { |assoc| assoc.delete('lastUpdateDate') }
          associations2.each { |assoc| assoc.delete('lastUpdateDate') }

          associations1 == associations2
        end
      end
    end

    # I wasn't sure if we really needed to test this, but I included it for the sake of ensuring that
    # deleting associations works as expected
    it 'creates associations', run_at: 'Thu, 24 Apr 2025 18:22:00 GMT' do
      VCR.use_cassette(
        'veteran_enrollment_system/associations/create_associations_success',
        { match_requests_on: %i[method uri body_ignoring_last_update_date], erb: true }
      ) do
        response = described_class.new(current_user).update_associations(
          updated_associations,
          '10-10EZR'
        )

        expect_successful_response_output(response, '2025-04-24T18:22:00Z')
      end
    end

    # I wasn't sure if we really needed to test this, but I included it for the sake of ensuring that
    # deleting associations works as expected
    it 'deletes associations', run_at: 'Thu, 24 Apr 2025 17:08:31 GMT' do
      VCR.use_cassette(
        'veteran_enrollment_system/associations/delete_associations_success',
        { match_requests_on: %i[method uri body_ignoring_last_update_date], erb: true }
      ) do
        response = described_class.new(current_user).update_associations(
          delete_associations,
          '10-10EZR'
        )

        expect_successful_response_output(response, '2025-04-24T17:08:31Z')
      end
    end

    context 'when a 200 response status is returned' do
      context "when the Associations API code returned is not 'partial_success'" do
        it 'increments StatsD, logs a success message, and returns a success response',
           run_at: 'Thu, 24 Apr 2025 17:08:31 GMT' do
          VCR.use_cassette(
            'veteran_enrollment_system/associations/update_associations_success',
            { match_requests_on: %i[method uri body_ignoring_last_update_date], erb: true }
          ) do
            response = described_class.new(current_user).update_associations(
              associations_maximum_incorrectly_ordered,
              '10-10EZR'
            )
            expect_successful_response_output(response, '2025-04-24T17:08:31Z')
          end
        end
      end

      context "when the Associations API code returned is a 'partial_success'" do
        before do
          allow_any_instance_of(described_class).to receive(:reorder_associations).and_return(
            delete_associations
          )
        end

        it 'increments StatsD, logs a partial success message, and returns a partial success response',
           run_at: 'Tue, 22 Apr 2025 22:03:48 GMT' do
          VCR.use_cassette(
            'veteran_enrollment_system/associations/update_associations_partial_success',
            { match_requests_on: %i[method uri body_ignoring_last_update_date], erb: true }
          ) do
            response = described_class.new(current_user).update_associations(
              delete_associations,
              '10-10EZR'
            )

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
                  }
                ],
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
        it 'increments StatsD, logs a failure message, and raises an exception',
           run_at: 'Thu, 24 Apr 2025 19:44:12 GMT' do
          VCR.use_cassette(
            'veteran_enrollment_system/associations/bad_request',
            { match_requests_on: %i[method uri body_ignoring_last_update_date], erb: true }
          ) do
            failure_message =
              'associations[0].relationType: Relation type is required, associations[1].role: Role is required, ' \
              'associations[0].role: Role is required, associations[3].role: Role is required, associations[2].role: ' \
              'Role is required, associations[3].relationType: Relation type is required, ' \
              'associations[2].relationType: Relation type is required, associations[1].relationType: Relation ' \
              'type is required'

            expect do
              described_class.new(current_user).update_associations(
                missing_required_fields,
                '10-10EZR'
              )
            end.to raise_error(
              an_instance_of(Common::Exceptions::BadRequest).and(having_attributes(errors: failure_message))
            )
            expect(StatsD).to have_received(:increment).with(
              'api.veteran_enrollment_system.associations.update_associations.failed'
            )
            expect(Rails.logger).to have_received(:error).with(
              "10-10EZR update associations failed: #{failure_message}"
            )
          end
        end
      end
    end
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
        timestamp:
      }
    )
  end
end
