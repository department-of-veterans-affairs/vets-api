# frozen_string_literal: true

require_relative '../../../rails_helper'

RSpec.describe AccreditedRepresentativePortal::V0::ClaimantController, type: :request do
  before do
    login_as(test_user)
    travel_to(time)
    allow_any_instance_of(Auth::ClientCredentials::Service).to receive(:get_token).and_return('fake_access_token')
  end

  let!(:poa_code) { '067' }
  let!(:other_poa_code) { 'z99' }

  let!(:test_user) do
    create(:representative_user, email: 'test@va.gov', icn: '123498767V234859', all_emails: ['test@va.gov'])
  end

  let!(:representative) do
    create(:representative,
           :vso,
           email: test_user.email,
           representative_id: Faker::Number.unique.number(digits: 6),
           poa_codes: [poa_code])
  end

  let!(:vso) { create(:organization, poa: poa_code, can_accept_digital_poa_requests: true) }
  let!(:other_vso) { create(:organization, poa: other_poa_code, can_accept_digital_poa_requests: true) }

  let(:claimant) { create(:user_account, icn: '1008714701V416111') }
  let!(:poa_request) do
    create(:power_of_attorney_request, :with_veteran_claimant, poa_code:, accredited_individual: representative,
                                                               accredited_organization: vso, claimant:)
  end
  let!(:other_poa_request) { create(:power_of_attorney_request, claimant:, poa_code: other_poa_code) }

  let(:time) { '2024-12-21T04:45:37.000Z' }
  let(:time_plus_one_day) { '2024-12-22T04:45:37.000Z' }
  let(:feature_flag_state) { true }

  describe 'GET /accredited_representative_portal/v0/claimant/search' do
    context 'when providing incomplete search params' do
      it 'returns a 400 error' do
        post('/accredited_representative_portal/v0/claimant/search', params: {
               first_name: 'John', last_name: 'Smith', dob: '1980-01-01', ssn: ''
             })
        expect(response).to have_http_status(:bad_request)
      end
    end

    context 'when providing complete search params' do
      context 'mpi returns no records' do
        it 'returns a 404 error' do
          VCR.use_cassette('mpi/find_candidate/icn_not_found') do
            post('/accredited_representative_portal/v0/claimant/search', params: {
                   first_name: 'John', last_name: 'Smith', dob: '1980-01-01', ssn: '666-66-6666'
                 })
            expect(response).to have_http_status(:not_found)
          end
        end
      end

      it 'returns only matching claimant' do
        VCR.use_cassette('mpi/find_candidate/valid_icn_full') do
          VCR.use_cassette(
            'accredited_representative_portal/requests/accredited_representative_portal/v0/claimant_spec/' \
            'lighthouse/benefits_claims/200_response'
          ) do
            post('/accredited_representative_portal/v0/claimant/search', params: {
                   first_name: 'John', last_name: 'Smith', dob: '1980-01-01', ssn: '666-66-6666'
                 })
          end
        end
        expect(response).to have_http_status(:ok)
        expect(parsed_response.dig('data', 'poaRequests').map { |poa| poa['id'] }).to eq([poa_request.id])
      end

      context 'there are multiple PoA request attempts' do
        let!(:other_poa_request) do
          create(:power_of_attorney_request,
                 :with_veteran_claimant,
                 :with_pending_form_submission,
                 poa_code:, accredited_individual: representative,
                 accredited_organization: vso, claimant:, created_at: 1.day.ago)
        end
        let!(:accepted_poa_request) do
          create(:power_of_attorney_request,
                 :with_veteran_claimant,
                 :with_acceptance,
                 poa_code:, accredited_individual: representative,
                 accredited_organization: vso, claimant:, created_at: 2.days.ago)
        end
        let!(:declined_poa_request) do
          create(:power_of_attorney_request,
                 :with_veteran_claimant,
                 :with_declination,
                 poa_code:, accredited_individual: representative,
                 accredited_organization: vso, claimant:, created_at: 3.days.ago)
        end

        it 'orders poa requests with pending first, then by date' do
          VCR.use_cassette('mpi/find_candidate/valid_icn_full') do
            VCR.use_cassette(
              'accredited_representative_portal/requests/accredited_representative_portal/v0/claimant_spec/' \
              'lighthouse/benefits_claims/200_response'
            ) do
              post('/accredited_representative_portal/v0/claimant/search', params: {
                     first_name: 'John', last_name: 'Smith', dob: '1980-01-01', ssn: '666-66-6666'
                   })
            end
          end
          expect(response).to have_http_status(:ok)
          expect(parsed_response.dig('data', 'poaRequests').map { |poa| poa['id'] }).to eq(
            [
              poa_request.id,
              other_poa_request.id,
              accepted_poa_request.id,
              declined_poa_request.id
            ]
          )
        end
      end

      context 'when there is a withdrawn poa request' do
        let!(:withdrawn_poa_request) do
          create(:power_of_attorney_request, :with_veteran_claimant,
                 poa_code:, accredited_individual: representative,
                 accredited_organization: vso, claimant:).tap do |req|
            req.mark_replaced!(create(:power_of_attorney_request))
          end
        end

        it 'does not return the withdrawn poa request' do
          VCR.use_cassette('mpi/find_candidate/valid_icn_full') do
            VCR.use_cassette(
              'accredited_representative_portal/requests/accredited_representative_portal/v0/claimant_spec/' \
              'lighthouse/benefits_claims/200_response'
            ) do
              post('/accredited_representative_portal/v0/claimant/search', params: {
                     first_name: 'John', last_name: 'Smith', dob: '1980-01-01', ssn: '666-66-6666'
                   })
            end
          end
          expect(response).to have_http_status(:ok)
          returned_ids = parsed_response.dig('data', 'poaRequests').map { |poa| poa['id'] }
          expect(returned_ids).not_to include(withdrawn_poa_request.id)
        end
      end
    end
  end

  describe 'GET /accredited_representative_portal/v0/claimant/:id' do
    let(:json_headers) { { 'ACCEPT' => 'application/json' } }
    let(:icn) { '1008714701V416111' }
    let(:identifier_id) { SecureRandom.uuid }

    let(:mpi_service) { instance_double(MPI::Service) }
    let(:identifier_obj) { instance_double(IcnTemporaryIdentifier, icn:) }

    before do
      # Let Pundit run; force policy to allow show? so authorization is performed
      allow_any_instance_of(AccreditedRepresentativePortal::ClaimantPolicy)
        .to receive(:show?)
        .and_return(true)

      # Stub identifier lookup on the real, namespaced model
      allow(AccreditedRepresentativePortal::IcnTemporaryIdentifier)
        .to receive(:find)
        .with(identifier_id)
        .and_return(identifier_obj)

      # If the controller references the un-namespaced constant, alias it safely for this spec.
      # Using stub_const ensures the constant exists in CI.
      stub_const('IcnTemporaryIdentifier', AccreditedRepresentativePortal::IcnTemporaryIdentifier)
      allow(IcnTemporaryIdentifier).to receive(:find).with(identifier_id).and_return(identifier_obj)

      allow(MPI::Service).to receive(:new).and_return(mpi_service)
    end

    context 'when the claimant exists in MPI' do
      let(:profile) do
        OpenStruct.new(
          given_names: ['John'],
          family_name: 'Smith',
          birth_date: '1980-01-01',
          ssn: '666-66-6666',
          home_phone: '555-555-5555',
          address: OpenStruct.new(
            street: '123 Main St',
            street2: 'Apt 4',
            city: 'Springfield',
            state: 'VA',
            postal_code: '12345'
          )
        )
      end

      let(:mpi_response) { OpenStruct.new(profile:) }

      before do
        allow(mpi_service).to receive(:find_profile_by_identifier).and_return(mpi_response)
      end

      it 'returns claimant profile fields' do
        get("/accredited_representative_portal/v0/claimant/#{identifier_id}", headers: json_headers)

        expect(response).to have_http_status(:ok)
        data = parsed_response.fetch('data')
        expect(data['first_name']).to eq('John')
        expect(data['last_name']).to eq('Smith')
        expect(data['birth_date']).to eq('1980-01-01')
      end

      it 'calls MPI with the ICN from the identifier' do
        get("/accredited_representative_portal/v0/claimant/#{identifier_id}", headers: json_headers)

        expect(mpi_service).to have_received(:find_profile_by_identifier).with(
          identifier: icn,
          identifier_type: MPI::Constants::ICN
        )
      end
    end

    context 'when MPI returns no profile' do
      before do
        allow(mpi_service).to receive(:find_profile_by_identifier).and_return(OpenStruct.new(profile: nil))
      end

      it 'returns 404 not found' do
        get("/accredited_representative_portal/v0/claimant/#{identifier_id}", headers: json_headers)
        expect(response).to have_http_status(:not_found)
      end
    end

    context 'when the temporary identifier does not exist' do
      before do
        allow(AccreditedRepresentativePortal::IcnTemporaryIdentifier)
          .to receive(:find)
          .with(identifier_id)
          .and_raise(ActiveRecord::RecordNotFound)
        allow(IcnTemporaryIdentifier).to receive(:find).with(identifier_id).and_raise(ActiveRecord::RecordNotFound)
      end

      it 'returns 404 not found' do
        get("/accredited_representative_portal/v0/claimant/#{identifier_id}", headers: json_headers)
        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
