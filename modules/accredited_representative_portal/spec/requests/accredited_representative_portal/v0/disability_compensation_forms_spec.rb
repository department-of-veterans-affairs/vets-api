# frozen_string_literal: true

require 'rails_helper'
require AccreditedRepresentativePortal::Engine.root.join('spec', 'rails_helper.rb')

RSpec.describe AccreditedRepresentativePortal::V0::DisabilityCompensationFormsController, type: :request do
  let(:poa_code) { '067' }
  let(:representative_user) do
    create(
      :representative_user,
      email: 'test@va.gov',
      icn: '123498767V234859',
      all_emails: ['test@va.gov']
    )
  end
  let!(:representative) do
    create(
      :representative,
      :vso,
      email: representative_user.email,
      representative_id: '357458',
      poa_codes: [poa_code]
    )
  end
  let!(:vso) { create(:organization, poa: poa_code) }
  let(:headers) { { 'CONTENT_TYPE' => 'application/json' } }

  before do
    login_as(representative_user)
  end

  describe 'POST #submit_all_claim' do
    let(:form_content) do
      {
        veteran: {
          ssn: '123456789',
          dateOfBirth: '1980-01-01',
          postalCode: '12345',
          fullName: {
            first: 'John',
            last: 'Doe'
          }
        },
        form526: {
          form526: {
            isVaEmployee: false,
            standardClaim: false,
            veteran: {
              currentlyVAEmployee: false
            },
            mailingAddress: {
              zipCode: '12345'
            },
            disabilities: [
              {
                name: 'PTSD',
                disabilityActionType: 'NEW'
              }
            ]
          }
        }
      }.to_json
    end

    context 'with valid form data and authorization' do
      let(:arp_vcr_path) do
        'accredited_representative_portal/requests/accredited_representative_portal/v0/representative_form_uploads_spec/'
      end
      let(:veteran_user_account) do
        create(:user_account, icn: '1012667145V762142')
      end

      before do
        allow_any_instance_of(Auth::ClientCredentials::Service).to receive(:get_token).and_return('<TOKEN>')
        allow_any_instance_of(AccreditedRepresentativePortal::SavedClaim::BenefitsClaims::DisabilityCompensation).to receive(:save).and_return(true)
        allow_any_instance_of(Form526Submission).to receive(:save!).and_return(true)
        allow_any_instance_of(Form526Submission).to receive(:start).and_return('test-job-id')
        allow(UserAccount).to receive(:find_by).and_return(veteran_user_account)
      end

      around do |example|
        VCR.insert_cassette("#{arp_vcr_path}mpi/valid_icn_full")
        VCR.insert_cassette("#{arp_vcr_path}lighthouse/200_type_organization_response")
        example.run
        VCR.eject_cassette("#{arp_vcr_path}lighthouse/200_type_organization_response")
        VCR.eject_cassette("#{arp_vcr_path}mpi/valid_icn_full")
      end

      it 'creates a submission and returns job_id' do
        post '/accredited_representative_portal/v0/disability_compensation_form/submit_all_claim',
             params: form_content,
             headers: headers

        if response.status == 500
          puts "Error response: #{response.body}"
        end

        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)).to have_key('data')
        expect(JSON.parse(response.body)['data']).to have_key('attributes')
        expect(JSON.parse(response.body)['data']['attributes']).to have_key('job_id')
      end
    end

    context 'with missing disabilities' do
      let(:arp_vcr_path) do
        'accredited_representative_portal/requests/accredited_representative_portal/v0/representative_form_uploads_spec/'
      end
      let(:veteran_user_account) do
        create(:user_account, icn: '1012667145V762142')
      end
      let(:form_content) do
        {
          veteran: {
            ssn: '123456789',
            dateOfBirth: '1980-01-01',
            postalCode: '12345',
            fullName: {
              first: 'John',
              last: 'Doe'
            }
          },
          form526: {
            form526: {
              isVaEmployee: false,
              standardClaim: false,
              veteran: {
                currentlyVAEmployee: false
              },
              mailingAddress: {
                zipCode: '12345'
              },
              disabilities: []
            }
          }
        }.to_json
      end

      before do
        allow_any_instance_of(Auth::ClientCredentials::Service).to receive(:get_token).and_return('<TOKEN>')
        allow_any_instance_of(AccreditedRepresentativePortal::SavedClaim::BenefitsClaims::DisabilityCompensation).to receive(:save).and_return(true)
        allow(UserAccount).to receive(:find_by).and_return(veteran_user_account)
      end

      around do |example|
        VCR.insert_cassette("#{arp_vcr_path}mpi/valid_icn_full")
        VCR.insert_cassette("#{arp_vcr_path}lighthouse/200_type_organization_response")
        example.run
        VCR.eject_cassette("#{arp_vcr_path}lighthouse/200_type_organization_response")
        VCR.eject_cassette("#{arp_vcr_path}mpi/valid_icn_full")
      end

      it 'returns an error' do
        post '/accredited_representative_portal/v0/disability_compensation_form/submit_all_claim',
             params: form_content,
             headers: headers

        expect(response).to have_http_status(:unprocessable_entity)
        expect(JSON.parse(response.body)['errors']).to be_present
      end
    end

    context 'when claimant cannot be found' do
      it 'returns not found status' do
        VCR.use_cassette('mpi/find_candidate/invalid_icn') do
          post '/accredited_representative_portal/v0/disability_compensation_form/submit_all_claim',
               params: form_content,
               headers: headers

          expect(response).to have_http_status(:not_found)
        end
      end
    end
  end
end
