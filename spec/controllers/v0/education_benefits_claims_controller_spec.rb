# frozen_string_literal: true

require 'rails_helper'
require 'support/controller_spec_helper'

RSpec.describe V0::EducationBenefitsClaimsController, type: :controller do
  it_behaves_like 'a controller that deletes an InProgressForm', 'education_benefits_claim', 'va1990', '22-1990'

  context 'with a user' do
    let(:user) { create(:user, :loa3, :with_terms_of_use_agreement) }

    it 'returns zero results for a user without submissions' do
      sign_in_as(user)
      create(:va10203, education_benefits_claim: create(:education_benefits_claim))
        .after_submit(create(:user, :loa3, uuid: SecureRandom.uuid, idme_uuid: nil))

      get(:stem_claim_status)

      body = JSON.parse response.body
      expect(response.content_type).to eq('application/json; charset=utf-8')
      expect(body['data']).to eq([])
    end

    it 'returns results for a user with submissions' do
      # swallow pdf_overflow_tracking. PdfFill::Filler.fill_form is slow and not what we're testing
      allow_any_instance_of(SavedClaim::EducationBenefits::VA1990).to receive(:pdf_overflow_tracking)
      sign_in_as(user)
      va10203 = create(:va10203, education_benefits_claim: create(:education_benefits_claim))
      va10203.after_submit(user)

      get(:stem_claim_status)

      body = JSON.parse response.body
      expect(response.content_type).to eq('application/json; charset=utf-8')
      expect(body['data'].length).to eq(1)
    end
  end

  context 'without a user' do
    it 'returns zero results' do
      get(:stem_claim_status)
      body = JSON.parse response.body
      expect(response.content_type).to eq('application/json; charset=utf-8')
      expect(body['data']).to eq([])
    end
  end

  describe '#create (when form is invalid)' do
    before { allow(StatsD).to receive(:increment) }

    context 'when claim save fails' do
      it 'increments failure stats and raises validation error' do
        invalid_params = {
          education_benefits_claim: {
            form: {}.to_json
          }
        }

        post :create, params: invalid_params

        # We're not going to catch the exception because it's being raised by the controller and
        # caught by middleware and converted to a 422
        # rubocop:disable RSpecRails/HttpStatus
        # it doesn't work with expect(response).to have_http_status(:unprocessable_entity)
        expect(response).to have_http_status(422)
        # rubocop:enable RSpecRails/HttpStatus
        body = JSON.parse response.body
        expect(body['errors']).to be_present

        expect(StatsD).to have_received(:increment).with('api.education_benefits_claim.221990.failure')
      end
    end
  end

  describe '#download_pdf' do
    let(:education_benefits_claim) { create(:education_benefits_claim) }
    let(:saved_claim) { education_benefits_claim.saved_claim }
    let(:temp_file_path) { '/tmp/test_file.pdf' }
    let(:file_contents) { 'fake pdf content' }

    before do
      allow(EducationBenefitsClaim)
        .to receive(:find)
        .with(education_benefits_claim.id.to_i)
        .and_return(education_benefits_claim)
      allow(SavedClaim)
        .to receive(:find)
        .with(education_benefits_claim.saved_claim_id)
        .and_return(education_benefits_claim.saved_claim)

      allow(PdfFill::Filler).to receive(:fill_form).and_return(temp_file_path)
      allow(File).to receive(:read).with(temp_file_path).and_return(file_contents)
      allow(File).to receive(:exist?).and_call_original
      allow(File).to receive(:exist?).with(temp_file_path).and_return(true)
      allow(File).to receive(:delete).with(temp_file_path)
      allow(controller).to receive(:send_data)
    end

    it 'successfully downloads a PDF' do
      get :download_pdf, params: { id: education_benefits_claim.id }

      expect(EducationBenefitsClaim).to have_received(:find).with(education_benefits_claim.id)
      expect(SavedClaim).to have_received(:find).with(education_benefits_claim.saved_claim_id)
      expect(PdfFill::Filler).to have_received(:fill_form).with(
        saved_claim,
        an_instance_of(String), # SecureRandom.uuid
        sign: false
      )
      expect(File).to have_received(:read).with(temp_file_path)
      expect(controller).to have_received(:send_data).with(
        file_contents,
        filename: "education_benefits_claim_#{saved_claim.id}.pdf",
        type: 'application/pdf',
        disposition: 'attachment'
      )
    end

    it 'cleans up the temporary file after successful download' do
      get :download_pdf, params: { id: education_benefits_claim.id }

      expect(File).to have_received(:exist?).with(temp_file_path)
      expect(File).to have_received(:delete).with(temp_file_path)
    end

    it 'does not try to delete file if it does not exist' do
      allow(File).to receive(:exist?).with(temp_file_path).and_return(false)

      get :download_pdf, params: { id: education_benefits_claim.id }

      expect(File).to have_received(:exist?).with(temp_file_path)
      expect(File).not_to have_received(:delete)
    end

    it 'does not try to delete file if temp_file_path is nil' do
      allow(PdfFill::Filler).to receive(:fill_form).and_return(nil)

      get :download_pdf, params: { id: education_benefits_claim.id }

      expect(File).not_to have_received(:exist?).with(nil)
      expect(File).not_to have_received(:delete)
    end

    context 'with string id parameter' do
      it 'converts string id to integer' do
        get :download_pdf, params: { id: education_benefits_claim.id.to_s }

        expect(EducationBenefitsClaim).to have_received(:find).with(education_benefits_claim.id)
      end
    end
  end
end
