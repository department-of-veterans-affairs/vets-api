# frozen_string_literal: true

require_relative '../../support/helpers/rails_helper'
require 'common/client/errors'

RSpec.describe 'user', type: :request do
  include JsonSchemaMatchers

  let(:contact_information_service) do
    if Flipper.enabled?(:va_v3_contact_information_service)
      VAProfile::V2::ContactInformation::Service
    else
      VAProfile::ContactInformation::Service
    end
  end

  describe 'GET /mobile/v1/user' do
    let!(:user) do
      sis_user(
        first_name: 'GREG',
        middle_name: 'A',
        last_name: 'ANDERSON',
        email: 'va.api.user+idme.008@gmail.com',
        birth_date: '1970-08-12',
        idme_uuid: 'b2fab2b5-6af0-45e1-a9e2-394347af91ef',
        cerner_facility_ids: %w[757 358 999],
        vha_facility_ids: %w[757 358 999]
      )
    end

    before { Flipper.enable_actor(:mobile_v1_lighthouse_facilities, user) }

    after { Flipper.disable(:mobile_v1_lighthouse_facilities) }

    context 'with no upstream errors' do
      before do
        VCR.use_cassette('mobile/payment_information/payment_information') do
          VCR.use_cassette('lighthouse/facilities/v1/200_facilities_757_358') do
            VCR.use_cassette('mobile/va_profile/demographics/demographics') do
              get '/mobile/v1/user', headers: sis_headers
            end
          end
        end
      end

      let(:attributes) { response.parsed_body.dig('data', 'attributes') }

      it 'returns an ok response' do
        expect(response).to have_http_status(:ok)
      end

      it 'returns a user profile response with the expected schema' do
        expect(response.body).to match_json_schema('v1/user')
      end

      it 'includes the users names' do
        expect(attributes['profile']).to include(
          'firstName' => 'GREG',
          'preferredName' => 'SAM',
          'middleName' => 'A',
          'lastName' => 'ANDERSON'
        )
      end

      it 'includes the users gender identity' do
        expect(attributes['profile']).to include(
          'genderIdentity' => 'F'
        )
      end

      it 'includes the users sign-in email' do
        expect(attributes['profile']).to include(
          'signinEmail' => 'va.api.user+idme.008@gmail.com'
        )
      end

      it 'includes the users contact email id' do
        expect(attributes.dig('profile', 'contactEmail', 'id')).to eq(456)
      end

      it 'includes the users contact email addrss' do
        expect(attributes.dig('profile', 'contactEmail', 'emailAddress')).to match(/person\d+@example.com/)
      end

      it 'includes the users birth date' do
        expect(attributes['profile']).to include(
          'birthDate' => '1970-08-12'
        )
      end

      it 'includes the expected residential address' do
        expect(attributes['profile']).to include(
          'residentialAddress' => {
            'id' => 123,
            'addressLine1' => '140 Rock Creek Rd',
            'addressLine2' => nil,
            'addressLine3' => nil,
            'addressPou' => 'RESIDENCE/CHOICE',
            'addressType' => 'DOMESTIC',
            'city' => 'Washington',
            'countryCodeIso3' => 'USA',
            'internationalPostalCode' => nil,
            'province' => nil,
            'stateCode' => 'DC',
            'zipCode' => '20011',
            'zipCodeSuffix' => nil
          }
        )
      end

      it 'includes the expected mailing address' do
        expect(attributes['profile']).to include(
          'mailingAddress' => {
            'id' => 124,
            'addressLine1' => '140 Rock Creek Rd',
            'addressLine2' => nil,
            'addressLine3' => nil,
            'addressPou' => 'CORRESPONDENCE',
            'addressType' => 'DOMESTIC',
            'city' => 'Washington',
            'countryCodeIso3' => 'USA',
            'internationalPostalCode' => nil,
            'province' => nil,
            'stateCode' => 'DC',
            'zipCode' => '20011',
            'zipCodeSuffix' => nil
          }
        )
      end

      it 'includes a home phone number' do
        expect(attributes['profile']['homePhoneNumber']).to include(
          {
            'id' => 789,
            'areaCode' => '303',
            'countryCode' => '1',
            'extension' => nil,
            'phoneNumber' => '5551234',
            'phoneType' => 'HOME'
          }
        )
      end

      it 'includes a mobile phone number' do
        expect(attributes['profile']['mobilePhoneNumber']).to include(
          {
            'id' => 790,
            'areaCode' => '303',
            'countryCode' => '1',
            'extension' => nil,
            'phoneNumber' => '5551234',
            'phoneType' => 'MOBILE'
          }
        )
      end

      it 'includes a work phone number' do
        expect(attributes['profile']['workPhoneNumber']).to include(
          {
            'id' => 791,
            'areaCode' => '303',
            'countryCode' => '1',
            'extension' => nil,
            'phoneNumber' => '5551234',
            'phoneType' => 'WORK'
          }
        )
      end

      it 'includes sign-in service' do
        expect(attributes['profile']['signinService']).to eq('idme')
      end

      it 'includes the service the user has access to' do
        expect(attributes['authorizedServices']).to eq(
          %w[
            appeals
            appointments
            claims
            decisionLetters
            directDepositBenefits
            directDepositBenefitsUpdate
            disabilityRating
            genderIdentity
            lettersAndDocuments
            militaryServiceHistory
            paymentHistory
            preferredName
            scheduleAppointments
            userProfileUpdate
          ]
        )
      end

      it 'includes a complete list of mobile api services (even if the user does not have access to them)' do
        expect(JSON.parse(response.body).dig('meta', 'availableServices')).to eq(
          %w[
            appeals
            appointments
            claims
            decisionLetters
            directDepositBenefits
            directDepositBenefitsUpdate
            disabilityRating
            genderIdentity
            lettersAndDocuments
            militaryServiceHistory
            paymentHistory
            preferredName
            prescriptions
            scheduleAppointments
            secureMessaging
            userProfileUpdate
          ]
        )
      end

      it 'includes a health attribute with user facilities and is_cerner_patient' do
        expect(attributes['health']).to include(
          {
            'isCernerPatient' => true,
            'facilities' => [
              {
                'facilityId' => '757',
                'isCerner' => true,
                'facilityName' => "Baxter Springs City Soldiers' Lot"
              },
              {
                'facilityId' => '358',
                'isCerner' => true,
                'facilityName' => 'Congressional Cemetery Government Lots'
              }
            ]
          }
        )
      end

      context 'when user object birth_date is nil' do
        let!(:user) { sis_user(birth_date: nil) }

        before do
          VCR.use_cassette('mobile/payment_information/payment_information') do
            VCR.use_cassette('lighthouse/facilities/v1/200_facilities_no_ids', match_requests_on: %i[method uri]) do
              VCR.use_cassette('mobile/va_profile/demographics/demographics') do
                get '/mobile/v1/user', headers: sis_headers
              end
            end
          end
        end

        it 'returns a nil birthdate' do
          expect(response).to have_http_status(:ok)
          expect(attributes['profile']).to include(
            'birthDate' => nil
          )
        end
      end
    end

    context 'when the upstream va profile service returns a 502' do
      before do
        allow_any_instance_of(contact_information_service).to receive(:get_person).and_raise(
          Common::Exceptions::BackendServiceException.new('VET360_502')
        )
      end

      it 'returns a service unavailable error' do
        VCR.use_cassette('lighthouse/facilities/v1/200_facilities_757_358', match_requests_on: %i[method uri]) do
          get '/mobile/v1/user', headers: sis_headers
        end

        expect(response).to have_http_status(:bad_gateway)
        expect(response.body).to match_json_schema('errors')
      end
    end

    context 'when the upstream va profile service returns a 404' do
      before do
        allow_any_instance_of(contact_information_service).to receive(:get_person).and_raise(
          Common::Exceptions::RecordNotFound.new(user.uuid)
        )
      end

      it 'returns a record not found error' do
        VCR.use_cassette('mobile/va_profile/demographics/demographics') do
          VCR.use_cassette('lighthouse/facilities/v1/200_facilities_757_358', match_requests_on: %i[method uri]) do
            get '/mobile/v1/user', headers: sis_headers
          end
        end

        expect(response).to have_http_status(:not_found)
        expect(response.body).to match_json_schema('errors')
        expect(response.parsed_body).to eq(
          {
            'errors' => [
              {
                'title' => 'Record not found',
                'detail' => "The record identified by #{user.uuid} could not be found",
                'code' => '404',
                'status' => '404'
              }
            ]
          }
        )
      end
    end

    context 'when the va profile service throws an argument error' do
      before do
        allow_any_instance_of(contact_information_service).to receive(:get_person).and_raise(
          ArgumentError.new
        )
      end

      it 'returns a bad gateway error' do
        get '/mobile/v1/user', headers: sis_headers

        expect(response).to have_http_status(:internal_server_error)
        expect(response.body).to match_json_schema('errors')
      end
    end

    context 'when the va profile service throws an client error' do
      before do
        allow_any_instance_of(contact_information_service).to receive(:get_person).and_raise(
          Common::Exceptions::BackendServiceException.new('VET360_502')
        )
      end

      it 'returns a bad gateway error' do
        VCR.use_cassette('lighthouse/facilities/v1/200_facilities_757_358', match_requests_on: %i[method uri]) do
          get '/mobile/v1/user', headers: sis_headers
        end

        expect(response).to have_http_status(:bad_gateway)
        expect(response.body).to match_json_schema('errors')
      end
    end

    context 'empty get_facility test' do
      before do
        VCR.use_cassette('mobile/payment_information/payment_information') do
          VCR.use_cassette('mobile/lighthouse_health/get_facility_v1_empty_757_358',
                           match_requests_on: %i[method uri]) do
            VCR.use_cassette('mobile/va_profile/demographics/demographics') do
              get '/mobile/v1/user', headers: sis_headers
            end
          end
        end
      end

      let(:attributes) { response.parsed_body.dig('data', 'attributes') }

      it 'returns empty appropriate facilities list' do
        expect(attributes['health']).to include(
          {
            'isCernerPatient' => true,
            'facilities' => [
              {
                'facilityId' => '757',
                'isCerner' => true,
                'facilityName' => ''
              },
              {
                'facilityId' => '358',
                'isCerner' => true,
                'facilityName' => ''
              }
            ]
          }
        )
      end
    end

    describe 'vet360 linking' do
      context 'when user has a vet360_id' do
        # let(:user) { FactoryBot.build(:iam_user) }

        # before { iam_sign_in(user) }

        it 'does not enqueue vet360 linking job' do
          expect(Mobile::V0::Vet360LinkingJob).not_to receive(:perform_async)

          VCR.use_cassette('mobile/payment_information/payment_information') do
            VCR.use_cassette('lighthouse/facilities/v1/200_facilities_757_358') do
              VCR.use_cassette('mobile/va_profile/demographics/demographics') do
                get '/mobile/v1/user', headers: sis_headers
              end
            end
          end
          expect(response).to have_http_status(:ok)
        end

        it 'flips mobile user vet360_linked to true if record exists' do
          Mobile::User.create(icn: user.icn, vet360_link_attempts: 1, vet360_linked: false)

          VCR.use_cassette('mobile/payment_information/payment_information') do
            VCR.use_cassette('lighthouse/facilities/v1/200_facilities_757_358') do
              VCR.use_cassette('mobile/va_profile/demographics/demographics') do
                get '/mobile/v1/user', headers: sis_headers

                expect(Mobile::User.where(icn: user.icn, vet360_link_attempts: 1, vet360_linked: true)).to exist
              end
            end
          end
          expect(response).to have_http_status(:ok)
        end
      end

      context 'when user does not have a vet360_id' do
        let!(:user) { sis_user(vet360_id: nil) }

        it 'enqueues vet360 linking job' do
          expect(Mobile::V0::Vet360LinkingJob).to receive(:perform_async)

          VCR.use_cassette('mobile/payment_information/payment_information') do
            VCR.use_cassette('lighthouse/facilities/v1/200_facilities_no_ids') do
              VCR.use_cassette('mobile/va_profile/demographics/demographics') do
                get '/mobile/v1/user', headers: sis_headers
              end
            end
          end
          expect(response).to have_http_status(:ok)
        end
      end
    end
  end
end
