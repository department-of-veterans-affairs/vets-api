# frozen_string_literal: true

require 'rails_helper'
require 'form1010_ezr/veteran_enrollment_system/associations/service'

RSpec.describe Form1010Ezr::VeteranEnrollmentSystem::Associations::Service do
  let(:associations) do
    fixture = get_fixture('form1010_ezr/valid_form_with_next_of_kin_and_emergency_contact')
    fixture['nextOfKins'].concat(fixture['emergencyContacts'])
  end
  let(:primary_next_of_kin) do
    associations.select { |association| association['contactType'] == 'Primary Next of Kin' }
  end
  let(:updated_associations) do
    [
      {
        'fullName' => {
          'first' => 'FirstNoKA',
          'middle' => 'MiddleNoKA',
          'last' => 'LastNoKA',
          'suffix' => 'Jr.'
        },
        'contactType' => 'Primary Next of Kin',
        'relationship' => 'SON',
        'address' => {
          'street' => 'NE 54th St',
          'street2' => 'Apt 7',
          'street3' => 'Unit 1222',
          'city' => 'guanajuato',
          'country' => 'MEX',
          'state' => 'guanajuato',
          'provinceCode' => 'guanajuato',
          'postalCode' => '84754'
        },
        'primaryPhone' => '9473747334'
      },
      {
        'fullName' => {
          'first' => 'FirstNoKB',
          'middle' => 'MiddleNoKB',
          'last' => 'LastNoKB'
        },
        'contactType' => 'Other Next of Kin',
        'relationship' => 'DAUGHTER',
        'address' => {
          'street' => '875 Updated Blvd',
          'street2' => 'Unit 532',
          'street3' => '',
          'city' => 'Tampa',
          'country' => 'USA',
          'state' => 'FL',
          'postalCode' => '33726-3942'
        },
        'primaryPhone' => '5435553234'
      },
      {
        'fullName' => {
          'first' => 'FirstECA',
          'middle' => 'MiddleECA',
          'last' => 'LastECA'
        },
        'contactType' => 'Emergency Contact',
        'relationship' => 'BROTHER',
        'address' => {
          'street' => '28 Parker St',
          'street2' => '',
          'street3' => '',
          'city' => 'Los Angeles',
          'country' => 'USA',
          'state' => 'CA',
          'postalCode' => '90038-1234'
        },
        'primaryPhone' => '5436422223'
      },
      {
        'fullName' => {
          'first' => 'FirstECB',
          'middle' => 'MiddleECB',
          'last' => 'LastECB'
        },
        'contactType' => 'Other emergency contact',
        'relationship' => 'UNRELATED FRIEND',
        'address' => {
          'street' => '875 Updated Blvd',
          'street2' => 'Unit 532',
          'street3' => '',
          'city' => 'Tampa',
          'country' => 'USA',
          'state' => 'FL',
          'postalCode' => '33726-3942'
        },
        'primaryPhone' => '1442342659'
      }
    ]
  end
  let(:associations_with_delete_indicators) do
    updated_associations.map { |association| association.deep_dup.merge('deleteIndicator' => true) }
  end
  let(:associations_with_missing_fields) do
    updated_associations.map { |association| association.except('contactType', 'relationship') }
  end
  let(:user) do
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
  let(:user_with_invalid_icn) do
    create(
      :evss_user,
      :loa3,
      icn: '1012829228V42403'
    )
  end

  before do
    # Because the 'lastUpdateDate' timestamps differ between the cassette's request body and when
    # they are set in the code, we'll ignore them when matching the request bodies on the put requests.
    VCR.configure do |config|
      config.register_request_matcher :body_ignoring_last_update_date do |r1, r2|
        # Parse both request bodies
        body1 = begin
          JSON.parse(r1.body)
        rescue
          {}
        end
        body2 = begin
          JSON.parse(r2.body)
        rescue
          {}
        end
        # Only mutate body2 if it's a PUT request
        if r2.method.to_s.downcase == 'put'
          [body1, body2].each do |body|
            associations = body['associations'] || []
            associations.each { |assoc| assoc.delete('lastUpdateDate') }
          end
        end
        # Compare the JSON structures
        JSON.dump(body1) == JSON.dump(body2)
      rescue JSON::ParserError
        false
      end
    end
  end

  # In the VES Associations API, insert, update, and delete are all handled by the same endpoint
  describe '#reconcile_and_update_associations' do
    before do
      allow(Rails.logger).to receive(:info)
      allow(Rails.logger).to receive(:error)
      allow(StatsD).to receive(:increment)
    end

    # I wasn't sure if we really needed to test this, but I included it for the sake of ensuring that
    # creating associations works as expected
    it 'reconciles and creates associations', run_at: 'Thu, 24 Jul 2025 15:30:34 GMT' do
      VCR.use_cassette(
        'form1010_ezr/veteran_enrollment_system/associations/create_associations_success',
        { match_requests_on: %i[method uri body_ignoring_last_update_date], erb: true }
      ) do
        response = described_class.new(user).reconcile_and_update_associations(associations)

        expect_successful_response_output(response, '2025-07-24T15:30:34Z')
      end
    end

    it 'reconciles and deletes associations', run_at: 'Thu, 24 Jul 2025 15:34:01 GMT' do
      VCR.use_cassette(
        'form1010_ezr/veteran_enrollment_system/associations/delete_associations_success',
        { match_requests_on: %i[method uri body_ignoring_last_update_date], erb: true }
      ) do
        # We're only sending the Primary Next of Kin, so the other associations should be deleted
        response =
          described_class.new(user).reconcile_and_update_associations(primary_next_of_kin)

        expect_successful_response_output(response, '2025-07-24T15:34:01Z')
      end
    end

    context 'when a 200 response status is returned' do
      context "when the Associations API code returned is not 'partial_success'" do
        it 'reconciles the associations, increments StatsD, logs a success message, and returns a success response',
           run_at: 'Thu, 24 Jul 2025 15:39:15 GMT' do
          VCR.use_cassette(
            'form1010_ezr/veteran_enrollment_system/associations/update_associations_success',
            { match_requests_on: %i[method uri body_ignoring_last_update_date], erb: true }
          ) do
            response = described_class.new(user).reconcile_and_update_associations(updated_associations)
            expect_successful_response_output(response, '2025-07-24T15:39:15Z')
          end
        end
      end

      context "when the Associations API code returned is a 'partial_success'" do
        before do
          allow_any_instance_of(
            VeteranEnrollmentSystem::Associations::Service
          ).to receive(:reorder_associations).and_return(
            described_class.new(user).send(
              :transform_associations,
              associations_with_delete_indicators
            )
          )
        end

        it 'reconciles the associations, increments StatsD, logs a partial success message, ' \
           'and returns a partial success response', run_at: 'Thu, 24 Jul 2025 15:42:43 GMT' do
          VCR.use_cassette(
            'form1010_ezr/veteran_enrollment_system/associations/update_associations_partial_success',
            { match_requests_on: %i[method uri body_ignoring_last_update_date], erb: true }
          ) do
            response =
              described_class.new(user).reconcile_and_update_associations(associations_with_delete_indicators)

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
                timestamp: '2025-07-24T15:42:43Z',
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
        before do
          allow_any_instance_of(
            Form1010Ezr::VeteranEnrollmentSystem::Associations::Reconciler
          ).to receive(:reconcile_associations).and_return(
            associations_with_missing_fields
          )
        end

        it 'increments StatsD, logs a failure message, and raises an exception',
           run_at: 'Thu, 24 Jul 2025 15:47:46 GMT' do
          VCR.use_cassette(
            'form1010_ezr/veteran_enrollment_system/associations/bad_request',
            { match_requests_on: %i[method uri body_ignoring_last_update_date], erb: true }
          ) do
            failure_message =
              'associations[2].role: Role is required, associations[1].relationType: Relation type is required, ' \
              'associations[3].role: Role is required, associations[1].role: Role is required, ' \
              'associations[0].role: Role is required, associations[0].relationType: Relation type is required, ' \
              'associations[2].relationType: Relation type is required, associations[3].relationType: Relation type ' \
              'is required'

            expect { described_class.new(user).reconcile_and_update_associations(associations_with_missing_fields) }
              .to raise_error do |e|
              expect(e).to be_a(Common::Exceptions::BadRequest)
              expect(e.errors.first.detail).to eq(failure_message)
            end
            expect(StatsD).to have_received(:increment).with(
              'api.veteran_enrollment_system.associations.update_associations.failed'
            )
            expect(Rails.logger).to have_received(:error).with(
              "10-10EZR update associations failed: #{failure_message}"
            )
          end
        end
      end

      context 'when an exception is raised' do
        before do
          allow_any_instance_of(
            Common::Client::Base
          ).to receive(:perform).and_raise(Common::Client::Errors::ClientError.new('some error'))
        end

        it 'increments StatsD, logs a failure message, and raises an exception' do
          expect { described_class.new(user).reconcile_and_update_associations(updated_associations) }
            .to raise_error do |e|
            expect(e).to be_a(Common::Client::Errors::ClientError)
            expect(e.message).to eq('some error')
          end
          expect(StatsD).to have_received(:increment).with(
            'api.1010ezr.veteran_enrollment_system.associations.reconcile_and_update_associations.failed'
          )
          expect(Rails.logger).to have_received(:error).with(
            '10-10EZR reconciling and updating associations failed: some error'
          )
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
