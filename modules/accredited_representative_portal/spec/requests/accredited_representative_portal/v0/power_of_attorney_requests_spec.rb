# frozen_string_literal: true

require_relative '../../../rails_helper'

def load_response_fixture(path_suffix)
  dir = './power_of_attorney_requests_spec/responses'
  File.expand_path("#{dir}/#{path_suffix}", __dir__)
      .then { |path| File.read(path) }
      .then { |json| JSON.parse(json) }
end

load_response_fixture('dependent_claimant_power_of_attorney_form.json')

load_response_fixture('veteran_claimant_power_of_attorney_form.json')

RSpec.describe AccreditedRepresentativePortal::V0::PowerOfAttorneyRequestsController, type: :request do
  before do
    login_as(test_user)
    travel_to(time)
    test_user
    representative
    vso
    other_vso
    poa_request
    other_poa_request
  end

  after do
    travel_back
  end

  # Use let instead of let! for test data that isn't required in every example
  let(:poa_code) { 'x23' }
  let(:time) { '2024-12-21T04:45:37.000Z' }
  let(:time_plus_one_day) { '2024-12-22T04:45:37.000Z' }
  let(:other_poa_code) { 'z99' }

  let(:test_user) do
    create(:representative_user, email: 'test@va.gov', icn: '123498767V234859', all_emails: ['test@va.gov'])
  end

  let(:representative) do
    create(:representative,
           :vso,
           email: test_user.email,
           representative_id: Faker::Number.unique.number(digits: 6),
           poa_codes: [poa_code])
  end

  let(:vso) { create(:organization, poa: poa_code, can_accept_digital_poa_requests: true) }
  let(:other_vso) { create(:organization, poa: other_poa_code, can_accept_digital_poa_requests: true) }

  let(:poa_request) { create(:power_of_attorney_request, :with_veteran_claimant, poa_code:) }
  let(:other_poa_request) do
    create(:power_of_attorney_request, :with_veteran_claimant, poa_code: other_poa_code,
                                                               accredited_organization: other_vso)
  end

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
          # Expected order: resolved1, resolved2, resolved3, unresolved poa_request (NULLS FIRST)
          let(:expected_resolved_desc_ids) do
            [poa_request.id, resolved_request1.id, resolved_request2.id, resolved_request3.id]
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
          expect(parsed_response['data']).to contain_exactly(
            hash_including('id' => poa_request.id, 'resolution' => nil),
            hash_including('id' => poa_requests[0].id, 'resolution' => nil),
            hash_including(
              'id' => poa_requests[1].id,
              'resolution' => hash_including('decisionType' => 'acceptance'),
              'powerOfAttorneyFormSubmission' => { 'status' => 'PENDING' }
            ),
            hash_including(
              'id' => poa_requests[2].id,
              'resolution' => hash_including('decisionType' => 'declination')
            ),
            hash_including(
              'id' => poa_requests[3].id,
              'resolution' => hash_including('type' => 'expiration')
            )
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

    context 'when providing as_selected_individual param' do
      let!(:unassigned) do
        # this should not show up in the results
        create(:power_of_attorney_request, :with_veteran_claimant, poa_code:)
      end
      let!(:assigned_list) do
        3.times.map { create(:power_of_attorney_request, poa_code:, accredited_individual: representative) }
      end

      before do
        allow_any_instance_of(AccreditedRepresentativePortal::PowerOfAttorneyHolderMemberships)
          .to receive(:registration_numbers)
          .and_return([representative.representative_id])
      end

      it 'returns the filtered list for the logged-in user' do
        get('/accredited_representative_portal/v0/power_of_attorney_requests?as_selected_individual=true')

        expect(response).to have_http_status(:ok)
        expect(response.parsed_body['data'].size).to eq(3)
        expect(response.parsed_body['data'].map { |poa| poa['id'] }).to match_array(assigned_list.map(&:id))
      end
    end

    context 'when providing a status param' do
      # Base request for pending status
      let!(:pending_request_base) { poa_request } # Created at 'time' (2024-12-21)

      # Additional requests with specific dates for sorting tests
      let!(:pending_request_earlier) do
        create(:power_of_attorney_request,
               :with_veteran_claimant,
               created_at: time.to_time - 2.days, # 2024-12-19
               poa_code:)
      end
      let!(:pending_request_later) do
        create(:power_of_attorney_request,
               :with_veteran_claimant,
               created_at: time.to_time + 1.day, # 2024-12-22
               poa_code:)
      end
      # NOTE: accepted_pending_request and accepted_failed_request are also pending
      # We need to give them specific created_at times for predictable sorting
      let!(:accepted_pending_request) do
        create(:power_of_attorney_request, :with_acceptance,
               created_at: time.to_time - 1.day, # 2024-12-20
               resolution_created_at: time_plus_one_day, # Resolution doesn't affect pending status
               poa_code:)
      end
      let!(:accepted_failed_request) do
        create(:power_of_attorney_request, :with_acceptance, :with_failed_form_submission,
               created_at: time.to_time + 2.days, # 2024-12-23
               resolution_created_at: time_plus_one_day, # Resolution doesn't affect pending status
               poa_code:)
      end

      # Processed requests with specific resolution dates
      let!(:declined_request) do
        create(:power_of_attorney_request, :with_declination,
               resolution_created_at: time.to_time - 1.day, # 2024-12-20
               poa_code:)
      end
      let!(:accepted_success_request) do
        create(:power_of_attorney_request, :with_acceptance, :with_form_submission,
               resolution_created_at: time.to_time + 1.day, # 2024-12-22
               poa_code:)
      end
      # Add another processed request for better sorting test
      let!(:accepted_success_request_earlier) do
        create(:power_of_attorney_request, :with_acceptance, :with_form_submission,
               resolution_created_at: time.to_time - 3.days, # 2024-12-18
               poa_code:)
      end

      # Requests that are neither pending nor processed (should not appear in filtered results)
      let!(:expired_request) do
        create(:power_of_attorney_request, :with_expiration, resolution_created_at: time, poa_code:)
      end
      let!(:replaced_request) do
        create(:power_of_attorney_request, :with_replacement, resolution_created_at: time, poa_code:)
      end

      let(:all_pending_ids) do
        [
          pending_request_earlier.id, # 2024-12-19
          accepted_pending_request.id, # 2024-12-20
          pending_request_base.id,     # 2024-12-21
          pending_request_later.id,    # 2024-12-22
          accepted_failed_request.id   # 2024-12-23
        ]
      end
      let(:all_processed_ids) do
        [
          accepted_success_request_earlier.id, # 2024-12-18
          declined_request.id,                  # 2024-12-20
          accepted_success_request.id           # 2024-12-22
        ]
      end

      # --- PENDING STATUS TESTS ---

      it 'returns pending requests sorted by created_at DESC by default' do
        get('/accredited_representative_portal/v0/power_of_attorney_requests?status=pending')

        expect(response).to have_http_status(:ok)
        expect(parsed_response['data'].length).to eq(5)
        ids = parsed_response['data'].map { |poa| poa['id'] }
        # Default is DESC: latest first
        expect(ids).to eq(all_pending_ids.reverse)
        expect(ids).not_to include(expired_request.id, replaced_request.id, *all_processed_ids)
      end

      it 'returns pending requests sorted by created_at ASC when specified' do
        get('/accredited_representative_portal/v0/power_of_attorney_requests',
            params: { status: 'pending', sort: { by: 'created_at', order: 'asc' } })

        expect(response).to have_http_status(:ok)
        expect(parsed_response['data'].length).to eq(5)
        ids = parsed_response['data'].map { |poa| poa['id'] }
        # Custom sort overrides default: ASC means earliest first
        expect(ids).to eq(all_pending_ids)
      end

      it 'returns pending requests sorted by created_at DESC when specified explicitly' do
        get('/accredited_representative_portal/v0/power_of_attorney_requests',
            params: { status: 'pending', sort: { by: 'created_at', order: 'desc' } })

        expect(response).to have_http_status(:ok)
        expect(parsed_response['data'].length).to eq(5)
        ids = parsed_response['data'].map { |poa| poa['id'] }
        # Explicit DESC sort matches default
        expect(ids).to eq(all_pending_ids.reverse)
      end

      # --- PROCESSED STATUS TESTS ---

      it 'returns processed requests sorted by resolved_at DESC by default' do
        get('/accredited_representative_portal/v0/power_of_attorney_requests?status=processed')

        expect(response).to have_http_status(:ok)
        expect(parsed_response['data'].length).to eq(3)
        ids = parsed_response['data'].map { |poa| poa['id'] }
        # Default is DESC: latest resolution first
        expect(ids).to eq(all_processed_ids.reverse)
        expect(ids).not_to include(expired_request.id, replaced_request.id, *all_pending_ids)
      end

      it 'returns processed requests sorted by resolved_at ASC when specified' do
        get('/accredited_representative_portal/v0/power_of_attorney_requests',
            params: { status: 'processed', sort: { by: 'resolved_at', order: 'asc' } })

        expect(response).to have_http_status(:ok)
        expect(parsed_response['data'].length).to eq(3)
        ids = parsed_response['data'].map { |poa| poa['id'] }
        # Custom sort overrides default: ASC means earliest resolution first
        expect(ids).to eq(all_processed_ids)
      end

      it 'returns processed requests sorted by resolved_at DESC when specified explicitly' do
        get('/accredited_representative_portal/v0/power_of_attorney_requests',
            params: { status: 'processed', sort: { by: 'resolved_at', order: 'desc' } })

        expect(response).to have_http_status(:ok)
        expect(parsed_response['data'].length).to eq(3)
        ids = parsed_response['data'].map { |poa| poa['id'] }
        # Explicit DESC sort matches default
        expect(ids).to eq(all_processed_ids.reverse)
      end

      # --- INVALID STATUS TEST ---
      it 'returns a 400 Bad Request for invalid status parameter' do
        get('/accredited_representative_portal/v0/power_of_attorney_requests?status=invalid_status')
        expect(response).to have_http_status(:bad_request)

        expect(parsed_response['errors']).to be_an(Array)
        expect(parsed_response['errors'].size).to be >= 1

        error_message = parsed_response['errors'].first
        expect(error_message).to be_a(String)
        status_error_pattern = /Invalid parameters.*?text="must be one of: pending, processed".*?path=\[:status\]/
        expect(error_message).to match(status_error_pattern)
      end

      # --- INVALID SORT WITH STATUS TEST ---
      it 'returns a 400 Bad Request for invalid sort field when status is provided' do
        get('/accredited_representative_portal/v0/power_of_attorney_requests',
            params: { status: 'pending', sort: { by: 'invalid_field', order: 'asc' } })
        expect(response).to have_http_status(:bad_request)

        expect(parsed_response['errors']).to be_an(Array)
        expect(parsed_response['errors'].size).to be >= 1

        error_message = parsed_response['errors'].first
        expect(error_message).to be_a(String)
        expect(error_message).to match(/Invalid parameters.*?path=\[:sort, :by\]/)
        expect(error_message).to match(/Invalid parameters.*?text="must be one of: created_at, resolved_at".*?path=\[:sort, :by\]/) # rubocop:disable Layout/LineLength
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
        expect(parsed_response['meta']['page']['totalPages']).to eq(3)
      end

      it 'returns the requested page of results' do
        get('/accredited_representative_portal/v0/power_of_attorney_requests?page[number]=2&page[size]=10')

        expect(response).to have_http_status(:ok)
        expect(parsed_response['data'].size).to eq(10)
        expect(parsed_response['meta']['page']['number']).to eq(2)
        expect(parsed_response['meta']['page']['size']).to eq(10)
        expect(parsed_response['meta']['page']['total']).to eq(26)
        expect(parsed_response['meta']['page']['totalPages']).to eq(3)
      end

      it 'returns the requested page size' do
        get('/accredited_representative_portal/v0/power_of_attorney_requests?page[size]=10')

        expect(response).to have_http_status(:ok)
        expect(parsed_response['data'].size).to eq(10)
        expect(parsed_response['meta']['page']['number']).to eq(1)
        expect(parsed_response['meta']['page']['size']).to eq(10)
        expect(parsed_response['meta']['page']['total']).to eq(26)
        expect(parsed_response['meta']['page']['totalPages']).to eq(3)
      end

      it 'returns 400 if page size is less than 1' do
        get('/accredited_representative_portal/v0/power_of_attorney_requests?page[size]=0')

        expect(response).to have_http_status(:bad_request)
        expect(parsed_response['errors'].join).to match(/Invalid parameters.*must be greater than or equal to 1/)
      end

      it 'returns an empty array for a page beyond the total pages' do
        get('/accredited_representative_portal/v0/power_of_attorney_requests?page[number]=10')

        expect(response).to have_http_status(:ok)
        expect(parsed_response['data']).to eq([])
        expect(parsed_response['meta']['page']['number']).to eq(10)
        expect(parsed_response['meta']['page']['totalPages']).to eq(3)
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

    context 'with redacted POA requests' do
      let!(:fully_redacted_poa_request) do
        create(:power_of_attorney_request, :with_veteran_claimant, :fully_redacted, poa_code:)
      end
      let!(:another_unredacted_request) do
        create(:power_of_attorney_request, :with_dependent_claimant, poa_code:, created_at: time)
      end

      it 'excludes fully redacted POA requests from the list' do
        get('/accredited_representative_portal/v0/power_of_attorney_requests')

        expect(response).to have_http_status(:ok)
        poa_ids = parsed_response['data'].map { |p| p['id'] }

        expect(poa_ids).to include(poa_request.id)
        expect(poa_ids).to include(another_unredacted_request.id)
        expect(poa_ids).not_to include(fully_redacted_poa_request.id)
      end

      it 'returns the correct total count excluding redacted requests in metadata' do
        get('/accredited_representative_portal/v0/power_of_attorney_requests')

        expect(response).to have_http_status(:ok)
        # Should count the 2 unredacted requests
        expect(parsed_response['meta']['page']['total']).to eq(2)
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

        it 'returns 404 Not Found for a fully redacted POA request' do
          fully_redacted_poa = create(:power_of_attorney_request, :with_veteran_claimant, :fully_redacted, poa_code:)
          get("/accredited_representative_portal/v0/power_of_attorney_requests/#{fully_redacted_poa.id}")

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

      context 'when POA request is withdrawn' do
        let!(:withdrawn_request) do
          resolution = create(:power_of_attorney_request_resolution, :replacement)
          resolution.power_of_attorney_request
        end

        it 'returns 404 Not Found' do
          get("/accredited_representative_portal/v0/power_of_attorney_requests/#{withdrawn_request.id}")

          expect(response).to have_http_status(:not_found)
          expect(response.parsed_body).to eq({ 'errors' => ['Record not found'] })
        end
      end
    end
  end
end
