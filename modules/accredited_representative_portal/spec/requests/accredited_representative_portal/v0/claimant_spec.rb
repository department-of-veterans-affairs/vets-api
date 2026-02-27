# frozen_string_literal: true

require_relative '../../../rails_helper'

# Ensure the top-level constant exists at file load time for verified doubles in CI.
IcnTemporaryIdentifier = AccreditedRepresentativePortal::IcnTemporaryIdentifier unless defined?(IcnTemporaryIdentifier)

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
    let(:identifier_id) { SecureRandom.uuid }
    let(:benefit_type) { 'compensation' }

    let(:path) { "/accredited_representative_portal/v0/claimant/#{identifier_id}" }

    # MPI test style aligned with other parts of the codebase
    let(:mpi_profile) do
      build(
        :mpi_profile,
        icn: '1008714701V416111',
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

    let(:icn) { mpi_profile.icn }
    let(:mpi_profile_response) { create(:find_profile_response, profile: mpi_profile) }

    let(:itf_service) { instance_double(BenefitsClaims::Service) }

    # allow have_received assertions without expect_any_instance_of
    let(:mpi_service) { instance_double(MPI::Service) }

    let(:claimant_details_service) { instance_double(AccreditedRepresentativePortal::ClaimantDetailsService) }

    before do
      # Ensure the controller's top-level constant exists in *all* envs (CI included)
      stub_const('IcnTemporaryIdentifier', AccreditedRepresentativePortal::IcnTemporaryIdentifier)

      # show uses lookup_icn per review
      allow(IcnTemporaryIdentifier).to receive(:lookup_icn).with(identifier_id).and_return(icn)

      # Policy: allow happy path POA check
      allow(AccreditedRepresentativePortal::ClaimantRepresentative).to receive(:find)
        .and_return(instance_double(AccreditedRepresentativePortal::ClaimantRepresentative))

      allow(MPI::Service).to receive(:new).and_return(mpi_service)
      allow(mpi_service).to receive(:find_profile_by_identifier).and_return(mpi_profile_response)

      # instantiates BenefitsClaims::Service per call; allow multiple instantiations.
      allow(BenefitsClaims::Service).to receive(:new).with(icn).and_return(itf_service, itf_service, itf_service)
      allow(itf_service).to receive(:get_intent_to_file).with(benefit_type).and_return({ 'status' => 'ok' })

      allow(AccreditedRepresentativePortal::ClaimantDetailsService).to receive(:new).with(
        icn:,
        benefit_type_param: benefit_type
      ).and_return(claimant_details_service)

      allow(claimant_details_service).to receive(:call).and_return(
        {
          data: {
            first_name: 'John',
            last_name: 'Smith',
            birth_date: '1980-01-01',
            itf: [{ 'status' => 'ok' }]
          }
        }
      )
    end

    context 'when the claimant exists in MPI' do
      it 'returns claimant profile fields' do
        get(path, params: { benefitType: benefit_type }, headers: json_headers)

        expect(response).to have_http_status(:ok)
        data = parsed_response.fetch('data')
        expect(data['first_name']).to eq('John')
        expect(data['last_name']).to eq('Smith')
        expect(data['birth_date']).to eq('1980-01-01')
      end

      it 'includes itf payload' do
        get(path, params: { benefitType: benefit_type }, headers: json_headers)

        expect(response).to have_http_status(:ok)
        expect(parsed_response.dig('data', 'itf')).to be_present
      end
    end

    context 'when itf lookup fails' do
      before do
        allow(itf_service).to receive(:get_intent_to_file).with(benefit_type).and_raise(StandardError, 'itf down')

        allow(claimant_details_service).to receive(:call).and_return(
          {
            data: {
              first_name: 'John',
              last_name: 'Smith',
              birth_date: '1980-01-01',
              itf: []
            }
          }
        )
      end

      it 'still returns claimant profile fields and itf is an empty array' do
        get(path, params: { benefitType: benefit_type }, headers: json_headers)

        expect(response).to have_http_status(:ok)
        data = parsed_response.fetch('data')
        expect(data['first_name']).to eq('John')
        expect(data['last_name']).to eq('Smith')
        expect(data['birth_date']).to eq('1980-01-01')
        expect(data['itf']).to eq([])
      end
    end

    context 'when rep does not have POA for claimant' do
      before do
        allow(AccreditedRepresentativePortal::ClaimantRepresentative)
          .to receive(:find)
          .and_raise(ActiveRecord::RecordNotFound)
      end

      it 'returns 403 forbidden' do
        get(path, params: { benefitType: benefit_type }, headers: json_headers)
        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'when MPI returns no profile' do
      before do
        allow(mpi_service).to receive(:find_profile_by_identifier).and_return(OpenStruct.new(profile: nil))

        allow(claimant_details_service).to receive(:call)
          .and_raise(Common::Exceptions::RecordNotFound, 'Claimant not found')
      end

      it 'returns 404 not found' do
        get(path, params: { benefitType: benefit_type }, headers: json_headers)
        expect(response).to have_http_status(:not_found)
      end
    end

    context 'when the temporary identifier does not exist' do
      before do
        allow(IcnTemporaryIdentifier).to receive(:lookup_icn).with(identifier_id).and_raise(ActiveRecord::RecordNotFound)
      end

      it 'returns 404 not found' do
        get(path, params: { benefitType: benefit_type }, headers: json_headers)
        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
