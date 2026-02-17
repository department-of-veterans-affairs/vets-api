# frozen_string_literal: true

require 'rails_helper'

require 'claims_evidence_api/uploader'
require 'digital_forms_api/service/submissions'

RSpec.describe DependentsBenefits::V0::ClaimsController do
  routes { DependentsBenefits::Engine.routes }

  before do
    allow(DependentsBenefits::PdfFill::Filler).to receive(:fill_form).and_return('tmp/pdfs/mock_form_final.pdf')
    sign_in_as(user)
    allow(Flipper).to receive(:enabled?).with(:dependents_module_enabled, instance_of(User)).and_return(true)
    allow_any_instance_of(SavedClaim).to receive(:pdf_overflow_tracking)
  end

  let(:user) { create(:evss_user) }
  let(:claim) { build(:dependents_claim) }
  let(:test_form) { build(:dependents_claim).parsed_form }
  let(:bgs_service) { double('BGS::Services') }
  let(:bgs_people) { double('BGS::People') }

  describe '#show' do
    context 'with a valid bgs response' do
      it 'returns a list of dependents' do
        VCR.use_cassette('bgs/claimant_web_service/dependents') do
          get(:show, params: { id: user.participant_id }, as: :json)
          expect(response).to have_http_status(:ok)
          expect(JSON.parse(response.body)['data']['type']).to eq('dependents')
        end
      end
    end

    context 'with an erroneous bgs response' do
      it 'returns no content' do
        allow_any_instance_of(BGS::DependentService).to receive(:get_dependents).and_raise(BGS::ShareError)
        get(:show, params: { id: user.participant_id }, as: :json)
        expect(response).to have_http_status(:bad_request)
      end
    end

    context 'with flipper disabled' do
      before do
        expect(Flipper).to receive(:enabled?).with(:dependents_module_enabled, instance_of(User)).and_return(false)
      end

      it 'returns forbidden error' do
        get(:show, params: { id: user.participant_id }, as: :json)
        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe 'POST create' do
    context 'with valid params and flipper enabled' do
      before do
        allow(Flipper).to receive(:enabled?).with(:dependents_digital_forms_api_submission_enabled, instance_of(User)).and_return(false)

        allow(BGS::Services).to receive(:new).and_return(bgs_service)
        allow(bgs_service).to receive(:people).and_return(bgs_people)
        allow(bgs_people).to receive(:find_person_by_ptcpnt_id).and_return({ file_nbr: '987654321' })
      end

      it 'validates successfully' do
        response = post(:create, params: test_form, as: :json)
        expect(response).to have_http_status(:ok)
      end

      it 'sets the user account on the claim' do
        post(:create, params: test_form, as: :json)
        claim = DependentsBenefits::PrimaryDependencyClaim.last
        expect(claim.user_account).to eq(user.user_account)
      end

      it 'creates saved claims' do
        expect do
          post(:create, params: test_form, as: :json)
        end.to change(
          DependentsBenefits::PrimaryDependencyClaim, :count
        ).by(1)
          .and change(
            DependentsBenefits::AddRemoveDependent, :count
          ).by(1)
          .and change(
            DependentsBenefits::SchoolAttendanceApproval, :count
          ).by(1).and change(
            SavedClaimGroup, :count
          ).by(3)
      end

      it 'creates SavedClaimGroup with current user data' do
        post(:create, params: test_form, as: :json)

        parent_group = SavedClaimGroup.last.parent_claim_group_for_child
        expected_user = { 'veteran_information' => { 'full_name' => { 'first' => user.first_name,
                                                                      'last' => user.last_name },
                                                     'common_name' => user.common_name,
                                                     'va_profile_email' => user.va_profile_email,
                                                     'email' => user.email,
                                                     'participant_id' => user.participant_id,
                                                     'ssn' => user.ssn,
                                                     'va_file_number' => '987654321',
                                                     'birth_date' => user.birth_date,
                                                     'uuid' => user.uuid,
                                                     'icn' => user.icn } }
        user_hash = JSON.parse(parent_group.user_data)
        expect(user_hash).to eq(expected_user)
      end

      it 'calls ClaimProcessor with correct parameters' do
        expect(DependentsBenefits::ClaimProcessor).to receive(:enqueue_submissions)
          .with(a_kind_of(Integer))

        post(:create, params: test_form, as: :json)
        expect(response).to have_http_status(:ok)
      end
    end

    context 'with invalid params' do
      let(:invalid_params) { { dependents_application: {} } }

      it 'returns validation errors' do
        post(:create, params: invalid_params, as: :json)
        expect(response).to have_http_status(:unprocessable_content)
      end

      it 'does not create a saved claim' do
        expect do
          post(:create, params: invalid_params, as: :json)
        end.not_to change(DependentsBenefits::PrimaryDependencyClaim, :count)
      end
    end

    context 'with flipper disabled' do
      before do
        allow(Flipper).to receive(:enabled?).with(:dependents_module_enabled, instance_of(User)).and_return(false)
      end

      it 'returns forbidden error' do
        post(:create, params: test_form, as: :json)
        expect(response).to have_http_status(:forbidden)
      end

      it 'does not create a saved claim' do
        expect do
          post(:create, params: test_form, as: :json)
        end.not_to change(DependentsBenefits::PrimaryDependencyClaim, :count)
      end
    end

    context 'with Forms API enabled' do
      let(:claim_information) do
        {
          proc_state: 'MANUAL_VAGOV',
          note_text: 'TEST',
          claim_name: '130 - Automated Dependency 686c',
          claim_label: '130DPNEBNADJ',
          participant_id: 'fake-participant-id'
        }
      end
      let(:dfa) { double(DigitalFormsApi::Service::Submissions) }
      let(:uploader) { double(ClaimsEvidenceApi::Uploader) }
      let(:response) { double('response', success?: true) }

      before do
        allow(Flipper).to receive(:enabled?).with(:dependents_digital_forms_api_submission_enabled, instance_of(User)).and_return(true)
        allow(DependentsBenefits::PrimaryDependencyClaim).to receive(:new).and_return(claim)
        allow(DigitalFormsApi::Service::Submissions).to receive(:new).and_return(dfa)
        allow(ClaimsEvidenceApi::Uploader).to receive(:new).and_return(uploader)
      end

      it 'submits to forms api and uploads evidence' do
        expect(claim).to receive(:claim_form_type).and_return('21-686c').thrice
        expect(claim).to receive(:get_claim_information).and_return(claim_information)
        expect(dfa).to receive(:submit).and_return(response)
        expect(uploader).to receive(:upload_evidence)

        expect_any_instance_of(DependentsBenefits::Monitor).to receive(:track_create_success)
        expect_any_instance_of(DependentsBenefits::NotificationEmail).to receive(:send_submitted_notification)

        post(:create, params: test_form, as: :json)
      end
    end
  end
end
