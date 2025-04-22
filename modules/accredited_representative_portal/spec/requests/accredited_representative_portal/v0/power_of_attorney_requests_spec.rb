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
    test_user
    accredited_individual
    representative
    vso
    other_vso
    poa_request
    other_poa_request
  end

  # Use let instead of let! for test data that isn't required in every example
  let(:poa_code) { 'x23' }
  let(:time) { '2024-12-21T04:45:37.000Z' }
  let(:time_plus_one_day) { '2024-12-22T04:45:37.000Z' }
  let(:other_poa_code) { 'z99' }

  let(:test_user) do
    create(:representative_user, email: 'test@va.gov', icn: '123498767V234859')
  end

  let(:accredited_individual) do
    create(:user_account_accredited_individual,
           user_account_email: test_user.email,
           user_account_icn: test_user.icn,
           poa_code:)
  end

  let(:representative) do
    create(:representative,
           :vso,
           representative_id: accredited_individual.accredited_individual_registration_number,
           poa_codes: [poa_code])
  end

  let(:vso) { create(:organization, poa: poa_code, can_accept_digital_poa_requests: true) }
  let(:other_vso) { create(:organization, poa: other_poa_code, can_accept_digital_poa_requests: true) }

  let(:poa_request) { create(:power_of_attorney_request, :with_veteran_claimant, poa_code:) }
  let(:other_poa_request) { create(:power_of_attorney_request, :with_veteran_claimant, poa_code: other_poa_code) }

  describe 'GET /accredited_representative_portal/v0/power_of_attorney_requests' do
    context 'when user belongs to a digital-POA-request-accepting VSO' do
      it 'allows access and returns the list of POA requests scoped to the user' do
        get('/accredited_representative_portal/v0/power_of_attorney_requests')

        expect(response).to have_http_status(:ok)
        expect(parsed_response['data'].size).to eq(1)
        expect(parsed_response['data'].first['id']).to eq(poa_request.id)
        expect(parsed_response['data'].map { |p| p['id'] }).not_to include(other_poa_request.id)
      end

      describe 'sorting' do
        context 'when sorting by created_at' do
          let!(:poa_requests) do
            [
              create(:power_of_attorney_request, :with_veteran_claimant,
                     created_at: time.to_time - 2.days,
                     poa_code:),
              create(:power_of_attorney_request, :with_veteran_claimant,
                     created_at: time.to_time - 1.day,
                     poa_code:),
              create(:power_of_attorney_request, :with_veteran_claimant,
                     created_at: time.to_time - 3.days,
                     poa_code:)
            ]
          end

          it 'sorts by created_at in ascending order' do
            get('/accredited_representative_portal/v0/power_of_attorney_requests',
                params: { sort: { by: 'created_at', order: 'asc' } })

            expect(response).to have_http_status(:ok)

            # check that they're sorted by created_at in ascending order
            ids = parsed_response.to_h['data'].map { |item| item['id'] }[0..2]
            expect(ids).to eq([poa_requests[2].id, poa_requests[0].id, poa_requests[1].id])
          end

          it 'sorts by created_at in descending order' do
            get('/accredited_representative_portal/v0/power_of_attorney_requests',
                params: { sort: { by: 'created_at', order: 'desc' } })

            expect(response).to have_http_status(:ok)

            # check that they're sorted by created_at in descending order
            ids = parsed_response.to_h['data'].map { |item| item['id'] }[1..3]
            expect(ids).to eq([poa_requests[1].id, poa_requests[0].id, poa_requests[2].id])
          end
        end

        context 'when sorting by resolved_at' do
          # NOTE: The base 'poa_request' from the outer 'before' block is unresolved.
          let!(:resolved_request1) do
            create(:power_of_attorney_request, :with_acceptance,
                   poa_code:, resolution_created_at: time.to_time - 1.day)
          end
          let!(:resolved_request2) do
            create(:power_of_attorney_request, :with_declination,
                   poa_code:, resolution_created_at: time.to_time - 2.days)
          end
          let!(:resolved_request3) do
            create(:power_of_attorney_request, :with_expiration,
                   poa_code:, resolution_created_at: time.to_time - 3.days)
          end
          # Expected order: resolved3, resolved2, resolved1, unresolved poa_request (NULLS LAST)
          let(:expected_resolved_asc_ids) do
            [resolved_request3.id, resolved_request2.id, resolved_request1.id, poa_request.id]
          end
          # Expected order: resolved1, resolved2, resolved3, unresolved poa_request (NULLS LAST)
          let(:expected_resolved_desc_ids) do
            [resolved_request1.id, resolved_request2.id, resolved_request3.id, poa_request.id]
          end

          it 'sorts by resolved_at in ascending order (NULLS LAST)' do
            get('/accredited_representative_portal/v0/power_of_attorney_requests',
                params: { sort: { by: 'resolved_at', order: 'asc' } })

            expect(response).to have_http_status(:ok)
            expect(parsed_response['data'].size).to eq(4) # 3 resolved + 1 unresolved
            ids = parsed_response.to_h['data'].map { |item| item['id'] }
            expect(ids).to eq(expected_resolved_asc_ids)
          end

          it 'sorts by resolved_at in descending order (NULLS LAST)' do
            get('/accredited_representative_portal/v0/power_of_attorney_requests',
                params: { sort: { by: 'resolved_at', order: 'desc' } })

            expect(response).to have_http_status(:ok)
            expect(parsed_response['data'].size).to eq(4) # 3 resolved + 1 unresolved
            ids = parsed_response.to_h['data'].map { |item| item['id'] }
            expect(ids).to eq(expected_resolved_desc_ids)
          end
        end

        it 'returns error for invalid sort field' do
          get('/accredited_representative_portal/v0/power_of_attorney_requests',
              params: { sort: { by: 'invalid_field' } })

          expect(response).to have_http_status(:bad_request)
          expect(parsed_response.to_h['errors']).to include(/Invalid parameters/)
        end

        it 'returns error for invalid sort order' do
          get('/accredited_representative_portal/v0/power_of_attorney_requests',
              params: { sort: { by: 'created_at', order: 'invalid' } })

          expect(response).to have_http_status(:bad_request)
          expect(parsed_response.to_h['errors']).to include(/Invalid parameters/)
        end
      end

      describe 'a variety of poa request configurations' do
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
          expect(parsed_response['data']).to eq(
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
      let(:pending_request2) { create(:power_of_attorney_request, created_at: time_plus_one_day, poa_code:) }
      let(:declined_request) do
        create(:power_of_attorney_request, :with_declination,
               resolution_created_at: time, poa_code:)
      end
      let(:accepted_pending_request) do
        create(:power_of_attorney_request, :with_acceptance, resolution_created_at: time_plus_one_day, poa_code:)
      end
      let(:accepted_failed_request) do
        create(:power_of_attorney_request, :with_acceptance, :with_failed_form_submission,
               resolution_created_at: time_plus_one_day, poa_code:)
      end
      let(:accepted_success_request) do
        create(:power_of_attorney_request, :with_acceptance, :with_form_submission,
               resolution_created_at: time_plus_one_day, poa_code:)
      end
      let(:replaced_request) do
        create(:power_of_attorney_request, :with_replacement, resolution_created_at: time, poa_code:)
      end
      let(:expired_request) do
        create(:power_of_attorney_request, :with_expiration, resolution_created_at: time_plus_one_day, poa_code:)
      end

      before do
        pending_request2
        declined_request
        accepted_pending_request
        accepted_failed_request
        accepted_success_request
        replaced_request
        expired_request
      end

      it 'returns the list of pending power of attorney requests sorted by creation ascending' do
        get('/accredited_representative_portal/v0/power_of_attorney_requests?status=pending')
        parsed_response = JSON.parse(response.body)
        expect(response).to have_http_status(:ok)
        expect(parsed_response['data'].length).to eq 4
        expect(parsed_response['data'].map { |poa| poa['id'] }).to include(poa_request.id)
        expect(parsed_response['data'].map { |poa| poa['id'] }).to include(pending_request2.id)
        expect(parsed_response['data'].map { |poa| poa['id'] }).to include(accepted_pending_request.id)
        expect(parsed_response['data'].map { |poa| poa['id'] }).to include(accepted_failed_request.id)
        expect(parsed_response['data'].map { |poa| poa['id'] }).not_to include(expired_request.id)
        expect(parsed_response['data'].map { |h| h['createdAt'] }).to eq(
          [time_plus_one_day, time, time, time]
        )
      end

      it 'returns the list of completed power of attorney requests sorted by resolution creation descending' do
        get('/accredited_representative_portal/v0/power_of_attorney_requests?status=processed')
        expect(response).to have_http_status(:ok)
        expect(parsed_response['data'].length).to eq 2
        expect(parsed_response['data'].map { |poa| poa['id'] }).to include(declined_request.id)
        expect(parsed_response['data'].map { |poa| poa['id'] }).to include(accepted_success_request.id)
        expect(parsed_response['data'].map { |poa| poa['id'] }).not_to include(expired_request.id)
        expect(parsed_response['data'].map { |h| h['resolution']['createdAt'] }).to eq([time_plus_one_day, time])
      end

      it 'returns a 400 Bad Request for invalid status parameter' do
        get('/accredited_representative_portal/v0/power_of_attorney_requests?status=invalid_status')
        expect(response).to have_http_status(:bad_request)
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
        expect(parsed_response['data']).to eq([])
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

    context 'with pagination' do
      let(:additional_poa_requests) do
        Array.new(25) do |i|
          create(:power_of_attorney_request,
                 :with_veteran_claimant,
                 created_at: Time.zone.parse(time) - i.days,
                 poa_code:)
        end
      end

      before do
        additional_poa_requests
      end

      it 'returns the first page of results by default' do
        get('/accredited_representative_portal/v0/power_of_attorney_requests')

        expect(response).to have_http_status(:ok)
        expect(parsed_response['data'].size).to eq(10)
        expect(parsed_response['meta']['page']['number']).to eq(1)
        expect(parsed_response['meta']['page']['size']).to eq(10)
        expect(parsed_response['meta']['page']['total']).to eq(26) # 25 additional + 1 initial
        expect(parsed_response['meta']['page']['total_pages']).to eq(3)
      end

      it 'returns the requested page of results' do
        get('/accredited_representative_portal/v0/power_of_attorney_requests?page[number]=2&page[size]=10')

        expect(response).to have_http_status(:ok)
        expect(parsed_response['data'].size).to eq(10)
        expect(parsed_response['meta']['page']['number']).to eq(2)
        expect(parsed_response['meta']['page']['size']).to eq(10)
        expect(parsed_response['meta']['page']['total']).to eq(26)
        expect(parsed_response['meta']['page']['total_pages']).to eq(3)
      end

      it 'returns the requested page size' do
        get('/accredited_representative_portal/v0/power_of_attorney_requests?page[size]=10')

        expect(response).to have_http_status(:ok)
        expect(parsed_response['data'].size).to eq(10)
        expect(parsed_response['meta']['page']['number']).to eq(1)
        expect(parsed_response['meta']['page']['size']).to eq(10)
        expect(parsed_response['meta']['page']['total']).to eq(26)
        expect(parsed_response['meta']['page']['total_pages']).to eq(3)
      end

      it 'returns 400 if page size is less than 10' do
        get('/accredited_representative_portal/v0/power_of_attorney_requests?page[size]=5')

        expect(response).to have_http_status(:bad_request)
        expect(parsed_response['errors'].join).to match(/Invalid parameters.*must be greater than or equal to 10/)
      end

      it 'returns an empty array for a page beyond the total pages' do
        get('/accredited_representative_portal/v0/power_of_attorney_requests?page[number]=10')

        expect(response).to have_http_status(:ok)
        expect(parsed_response['data']).to eq([])
        expect(parsed_response['meta']['page']['number']).to eq(10)
        expect(parsed_response['meta']['page']['total_pages']).to eq(3)
      end

      it 'properly validates and normalizes pagination parameters' do
        allow(AccreditedRepresentativePortal::PowerOfAttorneyRequestService::ParamsSchema)
          .to receive(:validate_and_normalize!)
          .and_return({ page: { number: 1, size: 20 } })

        get('/accredited_representative_portal/v0/power_of_attorney_requests')

        expect(response).to have_http_status(:ok)
        expect(AccreditedRepresentativePortal::PowerOfAttorneyRequestService::ParamsSchema)
          .to have_received(:validate_and_normalize!)
          .with(hash_including('controller', 'action'))
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
end
