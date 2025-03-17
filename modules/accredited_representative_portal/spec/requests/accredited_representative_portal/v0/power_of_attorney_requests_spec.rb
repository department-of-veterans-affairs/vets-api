# frozen_string_literal: true

require_relative '../../../rails_helper'

def load_response_fixture(path_suffix)
  dir = './power_of_attorney_requests_spec/responses'
  File.expand_path("#{dir}/#{path_suffix}", __dir__)
      .then { |path| File.read(path) }
      .then { |json| JSON.parse(json) }
end

dependent_claimant_power_of_attorney_form =
  load_response_fixture('dependent_claimant_power_of_attorney_form.json')

veteran_claimant_power_of_attorney_form =
  load_response_fixture('veteran_claimant_power_of_attorney_form.json')

RSpec.describe AccreditedRepresentativePortal::V0::PowerOfAttorneyRequestsController, type: :request do
  before do
    login_as(test_user)
    travel_to(time)
  end

  let!(:poa_code) { 'x23' }
  let!(:other_poa_code) { 'z99' }

  let!(:test_user) do
    create(:representative_user, email: 'test@va.gov', icn: '123498767V234859')
  end

  let!(:accredited_individual) do
    create(:user_account_accredited_individual,
           user_account_email: test_user.email,
           user_account_icn: test_user.icn,
           poa_code:)
  end

  let!(:representative) do
    create(:representative,
           :vso,
           representative_id: accredited_individual.accredited_individual_registration_number,
           poa_codes: [poa_code])
  end

  let!(:vso) { create(:organization, poa: poa_code, can_accept_digital_poa_requests: true) }
  let!(:other_vso) { create(:organization, poa: other_poa_code, can_accept_digital_poa_requests: true) }

  let!(:poa_request) { create(:power_of_attorney_request, :with_veteran_claimant, poa_code:) }
  let!(:other_poa_request) { create(:power_of_attorney_request, :with_veteran_claimant, poa_code: other_poa_code) }

  let(:time) { '2024-12-21T04:45:37.000Z' }
  let(:time_plus_one_day) { '2024-12-22T04:45:37.000Z' }

  describe 'GET /accredited_representative_portal/v0/power_of_attorney_requests' do
    context 'when user belongs to a digital-POA-request-accepting VSO' do
      it 'allows access and returns the list of POA requests scoped to the user' do
        get('/accredited_representative_portal/v0/power_of_attorney_requests')

        expect(response).to have_http_status(:ok)
        expect(parsed_response.to_h['data'].size).to eq(1)
        expect(parsed_response.to_h['data'].first['id']).to eq(poa_request.id)
        expect(parsed_response.to_h['data'].map { |p| p['id'] }).not_to include(other_poa_request.id)
      end

      describe 'pagination' do
        let!(:poa_requests) do
          (1..30).map do |i|
            create(:power_of_attorney_request, :with_veteran_claimant,
                   created_at: time.to_time - i.hours,
                   poa_code:)
          end
        end

        it 'returns the first page with default pagination' do
          get('/accredited_representative_portal/v0/power_of_attorney_requests')

          expect(response).to have_http_status(:ok)

          # Default pagination should return 10 items (first page)
          expect(parsed_response.to_h['data'].size).to eq(10)

          # Check pagination headers
          expect(response.headers['X-Total']).to eq('31')
          expect(response.headers['X-Total-Pages']).to eq('4')
          expect(response.headers['X-Per-Page']).to eq('10')
          expect(response.headers['X-Page']).to eq('1')
        end

        it 'returns the requested page with custom page size' do
          get('/accredited_representative_portal/v0/power_of_attorney_requests',
              params: { page: { number: 2, size: 10 } })

          expect(response).to have_http_status(:ok)

          # Second page should have remaining items (10 out of 31 total)
          expect(parsed_response.to_h['data'].size).to eq(10)

          # Check pagination headers
          expect(response.headers['X-Total']).to eq('31')
          expect(response.headers['X-Total-Pages']).to eq('4')
          expect(response.headers['X-Per-Page']).to eq('10')
          expect(response.headers['X-Page']).to eq('2')
        end

        it 'returns empty array for page beyond available data' do
          get('/accredited_representative_portal/v0/power_of_attorney_requests',
              params: { page: { number: 5, size: 10 } })

          expect(response).to have_http_status(:ok)
          expect(parsed_response.to_h['data']).to be_empty

          # Pagination headers should still be correct
          expect(response.headers['X-Total']).to eq('31')
          expect(response.headers['X-Total-Pages']).to eq('4')
          expect(response.headers['X-Per-Page']).to eq('10')
          expect(response.headers['X-Page']).to eq('5')
        end

        it 'returns errors for invalid pagination parameters' do
          get('/accredited_representative_portal/v0/power_of_attorney_requests',
              params: { page: { number: 0 } })

          expect(response).to have_http_status(:bad_request)
          expect(parsed_response.to_h['errors']).to include(/Invalid parameters/)

          get('/accredited_representative_portal/v0/power_of_attorney_requests',
              params: { page: { size: 5 } })

          expect(response).to have_http_status(:bad_request)
          expect(parsed_response.to_h['errors']).to include(/Invalid parameters/)

          get('/accredited_representative_portal/v0/power_of_attorney_requests',
              params: { page: { size: 101 } })

          expect(response).to have_http_status(:bad_request)
          expect(parsed_response.to_h['errors']).to include(/Invalid parameters/)
        end
      end

      describe 'a variety of POA request configurations' do
        let(:poa_requests) do
          [].tap do |memo|
            memo <<
              create(
                :power_of_attorney_request,
                :with_veteran_claimant,
                poa_code:
              )

            resolution_a =
              create(
                :power_of_attorney_request_resolution,
                :acceptance,
                :with_dependent_claimant,
                poa_code:
              )

            resolution_b =
              create(
                :power_of_attorney_request_resolution,
                :declination,
                :with_dependent_claimant,
                poa_code:
              )

            resolution_c =
              create(
                :power_of_attorney_request_resolution,
                :expiration,
                :with_dependent_claimant,
                poa_code:
              )

            memo << resolution_a.power_of_attorney_request
            memo << resolution_b.power_of_attorney_request
            memo << resolution_c.power_of_attorney_request
          end
        end

        it 'returns a list of power of attorney requests' do
          poa_requests

          get('/accredited_representative_portal/v0/power_of_attorney_requests')

          expect(response).to have_http_status(:ok)
          expect(parsed_response.to_h['data']).to eq(
            [
              {
                'id' => poa_request.id,
                'claimantId' => poa_request.claimant_id,
                'createdAt' => time,
                'expiresAt' => (Time.zone.parse(time) + 60.days).iso8601(3),
                'powerOfAttorneyForm' => veteran_claimant_power_of_attorney_form,
                'resolution' => nil,
                'accreditedIndividual' => {
                  'id' => poa_request.accredited_individual.id,
                  'fullName' => "#{poa_request.accredited_individual.first_name} " \
                                "#{poa_request.accredited_individual.last_name}"
                },
                'powerOfAttorneyHolder' => {
                  'type' => 'veteran_service_organization',
                  'name' => poa_request.accredited_organization.name,
                  'id' => poa_request.accredited_organization.poa
                }
              },
              {
                'id' => poa_requests[0].id,
                'claimantId' => poa_requests[0].claimant_id,
                'createdAt' => time,
                'expiresAt' => (Time.zone.parse(time) + 60.days).iso8601(3),
                'powerOfAttorneyForm' => veteran_claimant_power_of_attorney_form,
                'resolution' => nil,
                'accreditedIndividual' => {
                  'id' => poa_requests[0].accredited_individual.id,
                  'fullName' => "#{poa_requests[0].accredited_individual.first_name} " \
                                "#{poa_requests[0].accredited_individual.last_name}"
                },
                'powerOfAttorneyHolder' => {
                  'type' => 'veteran_service_organization',
                  'name' => poa_requests[0].accredited_organization.name,
                  'id' => poa_requests[0].accredited_organization.poa
                }
              },
              {
                'id' => poa_requests[1].id,
                'claimantId' => poa_requests[1].claimant_id,
                'createdAt' => time,
                'expiresAt' => nil,
                'powerOfAttorneyForm' => dependent_claimant_power_of_attorney_form,
                'resolution' => {
                  'id' => poa_requests[1].resolution.id,
                  'type' => 'decision',
                  'createdAt' => time,
                  'creatorId' => poa_requests[1].resolution.resolving.creator_id,
                  'decisionType' => 'acceptance'
                },
                'accreditedIndividual' => {
                  'id' => poa_requests[1].accredited_individual.id,
                  'fullName' => "#{poa_requests[1].accredited_individual.first_name} " \
                                "#{poa_requests[1].accredited_individual.last_name}"
                },
                'powerOfAttorneyHolder' => {
                  'type' => 'veteran_service_organization',
                  'name' => poa_requests[1].accredited_organization.name,
                  'id' => poa_requests[1].accredited_organization.poa
                },
                'powerOfAttorneyFormSubmission' => {
                  'status' => 'PENDING'
                }
              },
              {
                'id' => poa_requests[2].id,
                'claimantId' => poa_requests[2].claimant_id,
                'createdAt' => time,
                'expiresAt' => nil,
                'powerOfAttorneyForm' => dependent_claimant_power_of_attorney_form,
                'resolution' => {
                  'id' => poa_requests[2].resolution.id,
                  'type' => 'decision',
                  'createdAt' => time,
                  'creatorId' => poa_requests[2].resolution.resolving.creator_id,
                  'reason' => 'Didn\'t authorize treatment record disclosure',
                  'decisionType' => 'declination'
                },
                'accreditedIndividual' => {
                  'id' => poa_requests[2].accredited_individual.id,
                  'fullName' => "#{poa_requests[2].accredited_individual.first_name} " \
                                "#{poa_requests[2].accredited_individual.last_name}"
                },
                'powerOfAttorneyHolder' => {
                  'type' => 'veteran_service_organization',
                  'name' => poa_requests[2].accredited_organization.name,
                  'id' => poa_requests[2].accredited_organization.poa
                }
              },
              {
                'id' => poa_requests[3].id,
                'claimantId' => poa_requests[3].claimant_id,
                'createdAt' => time,
                'expiresAt' => nil,
                'powerOfAttorneyForm' => dependent_claimant_power_of_attorney_form,
                'resolution' => {
                  'id' => poa_requests[3].resolution.id,
                  'type' => 'expiration',
                  'createdAt' => time
                },
                'accreditedIndividual' => {
                  'id' => poa_requests[3].accredited_individual.id,
                  'fullName' => "#{poa_requests[3].accredited_individual.first_name} " \
                                "#{poa_requests[3].accredited_individual.last_name}"
                },
                'powerOfAttorneyHolder' => {
                  'type' => 'veteran_service_organization',
                  'name' => poa_requests[3].accredited_organization.name,
                  'id' => poa_requests[3].accredited_organization.poa
                }
              }
            ]
          )

          # Check pagination headers
          expect(response.headers['X-Total']).to eq('5')
          expect(response.headers['X-Total-Pages']).to eq('1')
          expect(response.headers['X-Per-Page']).to eq('10')
          expect(response.headers['X-Page']).to eq('1')
        end
      end
    end

    context 'when user has no associated VSOs' do
      before do
        representative.destroy!
      end

      it 'returns 403 Forbidden' do
        get('/accredited_representative_portal/v0/power_of_attorney_requests')
        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'when providing a status param' do
      let!(:pending_request2) { create(:power_of_attorney_request, created_at: time_plus_one_day, poa_code:) }
      let!(:declined_request) do
        create(:power_of_attorney_request, :with_declination,
               resolution_created_at: time, poa_code:)
      end
      let!(:accepted_pending_request) do
        create(:power_of_attorney_request, :with_acceptance, resolution_created_at: time_plus_one_day, poa_code:)
      end
      let!(:accepted_failed_request) do
        create(:power_of_attorney_request, :with_acceptance, :with_failed_form_submission,
               resolution_created_at: time_plus_one_day, poa_code:)
      end
      let!(:accepted_success_request) do
        create(:power_of_attorney_request, :with_acceptance, :with_form_submission,
               resolution_created_at: time_plus_one_day, poa_code:)
      end
      let!(:replaced_request) do
        create(:power_of_attorney_request, :with_replacement, resolution_created_at: time, poa_code:)
      end
      let!(:expired_request) do
        create(:power_of_attorney_request, :with_expiration, resolution_created_at: time_plus_one_day, poa_code:)
      end

      it 'returns the list of pending power of attorney requests sorted by creation ascending' do
        get('/accredited_representative_portal/v0/power_of_attorney_requests?status=pending')
        expect(response).to have_http_status(:ok)
        expect(parsed_response.to_h['data'].length).to eq 4
        expect(parsed_response.to_h['data'].map { |poa| poa['id'] }).to include(poa_request.id)
        expect(parsed_response.to_h['data'].map { |poa| poa['id'] }).to include(pending_request2.id)
        expect(parsed_response.to_h['data'].map { |poa| poa['id'] }).to include(accepted_pending_request.id)
        expect(parsed_response.to_h['data'].map { |poa| poa['id'] }).to include(accepted_failed_request.id)
        expect(parsed_response.to_h['data'].map { |poa| poa['id'] }).not_to include(expired_request.id)
        expect(parsed_response.to_h['data'].map { |h| h['createdAt'] }).to eq(
          [time_plus_one_day, time, time, time]
        )

        # Check pagination headers
        expect(response.headers['X-Total']).to eq('4')
        expect(response.headers['X-Total-Pages']).to eq('1')
        expect(response.headers['X-Per-Page']).to eq('10')
        expect(response.headers['X-Page']).to eq('1')
      end

      it 'returns the list of completed power of attorney requests sorted by resolution creation descending' do
        get('/accredited_representative_portal/v0/power_of_attorney_requests?status=processed')
        expect(response).to have_http_status(:ok)
        expect(parsed_response.to_h['data'].length).to eq 2
        expect(parsed_response.to_h['data'].map { |poa| poa['id'] }).to include(declined_request.id)
        expect(parsed_response.to_h['data'].map { |poa| poa['id'] }).to include(accepted_success_request.id)
        expect(parsed_response.to_h['data'].map { |poa| poa['id'] }).not_to include(expired_request.id)
        expect(parsed_response.to_h['data'].map { |h| h['resolution']['createdAt'] }).to eq([time_plus_one_day, time])

        # Check pagination headers
        expect(response.headers['X-Total']).to eq('2')
        expect(response.headers['X-Total-Pages']).to eq('1')
        expect(response.headers['X-Per-Page']).to eq('10')
        expect(response.headers['X-Page']).to eq('1')
      end

      describe 'pagination with status filter' do
        before do
          # Create additional pending requests to test pagination with status filter
          15.times do |i|
            create(:power_of_attorney_request, created_at: time.to_time - i.days, poa_code:)
          end

          # Create additional processed requests
          10.times do |i|
            create(:power_of_attorney_request, :with_declination,
                   resolution_created_at: time.to_time - i.days, poa_code:)
          end
        end

        it 'paginates pending requests correctly' do
          path = '/accredited_representative_portal/v0/power_of_attorney_requests' \
                 '?status=pending&page[number]=1&page[size]=10'
          get path

          expect(response).to have_http_status(:ok)

          expect(parsed_response.to_h['data'].length).to eq(10)

          # Check pagination headers
          expect(response.headers['X-Total']).to eq('19')
          expect(response.headers['X-Total-Pages']).to eq('2')
          expect(response.headers['X-Per-Page']).to eq('10')
          expect(response.headers['X-Page']).to eq('1')
        end

        it 'paginates processed requests correctly' do
          path = '/accredited_representative_portal/v0/power_of_attorney_requests' \
                 '?status=processed&page[number]=1&page[size]=10'
          get path

          expect(response).to have_http_status(:ok)

          # First page with size 5 of processed requests
          expect(parsed_response.to_h['data'].length).to eq(10)

          # Check pagination headers
          expect(response.headers['X-Total']).to eq('12')
          expect(response.headers['X-Total-Pages']).to eq('2')
          expect(response.headers['X-Per-Page']).to eq('10')
          expect(response.headers['X-Page']).to eq('1')
        end
      end
    end

    context 'when user has a VSO but no POA requests' do
      before do
        poa_request.power_of_attorney_form.destroy!
        poa_request.destroy!
      end

      it 'returns an empty collection' do
        get('/accredited_representative_portal/v0/power_of_attorney_requests')

        expect(response).to have_http_status(:ok)
        expect(parsed_response.to_h['data']).to eq([])

        # Check pagination headers for empty collection
        expect(response.headers['X-Total']).to eq('0')
        expect(response.headers['X-Total-Pages']).to eq('1')
        expect(response.headers['X-Per-Page']).to eq('10')
        expect(response.headers['X-Page']).to eq('1')
      end
    end

    context 'when user\'s VSO does not accept digital POAs' do
      before do
        vso.update!(can_accept_digital_poa_requests: false)
      end

      it 'returns 403 Forbidden' do
        get('/accredited_representative_portal/v0/power_of_attorney_requests')
        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe 'GET /accredited_representative_portal/v0/power_of_attorney_requests/:id' do
    context 'when user is authorized' do
      it 'returns the details of the POA request' do
        get("/accredited_representative_portal/v0/power_of_attorney_requests/#{poa_request.id}")

        expect(response).to have_http_status(:ok)
        expect(parsed_response['id']).to eq(poa_request.id)
      end
    end

    context 'when user is unauthorized (trying to access another VSO\'s POA request)' do
      it 'returns 404 Not Found' do
        get("/accredited_representative_portal/v0/power_of_attorney_requests/#{other_poa_request.id}")

        expect(response).to have_http_status(:not_found)
      end
    end

    context 'when user\'s VSO does not accept digital POAs' do
      before do
        vso.update!(can_accept_digital_poa_requests: false)
      end

      it 'returns 403 Forbidden' do
        get("/accredited_representative_portal/v0/power_of_attorney_requests/#{poa_request.id}")

        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'when POA request does not exist' do
      it 'returns 404 Not Found' do
        get('/accredited_representative_portal/v0/power_of_attorney_requests/nonexistent')

        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
