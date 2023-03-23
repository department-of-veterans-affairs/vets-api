# frozen_string_literal: true

require 'rails_helper'

RSpec.describe V0::CaregiversAssistanceClaimsController, type: :controller do
  describe '::auditor' do
    it 'is an instance of Form1010cg::Auditor' do
      expect(described_class::AUDITOR).to be_an_instance_of(Form1010cg::Auditor)
    end

    it 'is using Rails.logger' do
      expect(described_class::AUDITOR.logger).to eq(Rails.logger)
    end
  end

  it 'inherits from ActionController::API' do
    expect(described_class.ancestors).to include(ActionController::API)
  end

  shared_examples '10-10CG request with missing param: caregivers_assistance_claim' do |controller_action|
    before do
      expect(Form1010cg::SubmissionJob).not_to receive(:perform_async)
    end

    it 'requires "caregivers_assistance_claim" param' do
      post controller_action, params: {}

      expect(response).to have_http_status(:bad_request)

      res_body = JSON.parse(response.body)

      expect(res_body['errors'].size).to eq(1)
      expect(res_body['errors'][0]).to eq(
        {
          'title' => 'Missing parameter',
          'detail' => 'The required parameter "caregivers_assistance_claim", is missing',
          'code' => '108',
          'status' => '400'
        }
      )
    end
  end

  shared_examples '10-10CG request with missing param: form' do |controller_action|
    before do
      expect(Form1010cg::SubmissionJob).not_to receive(:perform_async)
    end

    it 'requires "caregivers_assistance_claim.form" param' do
      post controller_action, params: { caregivers_assistance_claim: { form: nil } }

      expect(response).to have_http_status(:bad_request)
      res_body = JSON.parse(response.body)

      expect(res_body['errors'].size).to eq(1)
      expect(res_body['errors'][0]).to eq(
        {
          'title' => 'Missing parameter',
          'detail' => 'The required parameter "form", is missing',
          'code' => '108',
          'status' => '400'
        }
      )
    end
  end

  shared_examples '10-10CG request with invalid form data' do |controller_action|
    let(:form_data) { '{}' }
    let(:params) { { caregivers_assistance_claim: { form: form_data } } }
    let(:claim) { build(:caregivers_assistance_claim, form: form_data) }

    before do
      expect(Form1010cg::SubmissionJob).not_to receive(:perform_async)
    end

    it 'builds a claim and raises its errors' do
      expect(SavedClaim::CaregiversAssistanceClaim).to receive(:new).with(
        form: form_data
      ).and_return(
        claim
      )

      expect(Form1010cg::Service).not_to receive(:new).with(claim)

      post(controller_action, params:)

      log = PersonalInformationLog.last
      expect(log.error_class).to eq('1010CGValidationError')
      expect(log.data).to eq({ 'form' => {} })

      res_body = JSON.parse(response.body)

      expect(response.status).to eq(422)

      expect(res_body['errors']).to be_present
      expect(res_body['errors'].size).to eq(2)
      expect(res_body['errors'][0]['title']).to include(
        "did not contain a required property of 'veteran'"
      )
      expect(res_body['errors'][0]['code']).to eq('100')
      expect(res_body['errors'][0]['status']).to eq('422')
      expect(res_body['errors'][1]['title'].split("\n")).to eq(
        [
          "Form The property '#/' of type object did not match one or more of the required schemas. The schema specific errors were:", # rubocop:disable Layout/LineLength
          '',
          '- anyOf #0:',
          "    - The property '#/' did not contain a required property of 'primaryCaregiver'",
          '- anyOf #1:',
          "    - The property '#/' did not contain a required property of 'secondaryCaregiverOne'"
        ]
      )
      expect(res_body['errors'][1]['code']).to eq('100')
      expect(res_body['errors'][1]['status']).to eq('422')
    end
  end

  describe '#create' do
    let(:claim) { build(:caregivers_assistance_claim) }

    it_behaves_like '10-10CG request with missing param: caregivers_assistance_claim', :create do
      before do
        expect(Raven).not_to receive(:tags_context).with(claim_guid: claim.guid)

        expect(described_class::AUDITOR).to receive(:record).with(:submission_attempt)
        expect(described_class::AUDITOR).to receive(:record).with(
          :submission_failure_client_data,
          errors: ['param is missing or the value is empty: caregivers_assistance_claim']
        )
      end
    end

    it_behaves_like '10-10CG request with missing param: form', :create do
      before do
        expect(Raven).not_to receive(:tags_context).with(claim_guid: claim.guid)

        expect(described_class::AUDITOR).to receive(:record).with(:submission_attempt)
        expect(described_class::AUDITOR).to receive(:record).with(
          :submission_failure_client_data,
          errors: ['param is missing or the value is empty: form']
        )
      end
    end

    it_behaves_like '10-10CG request with invalid form data', :create do
      let(:expected_errors) do
        # Need to build a duplicate claim in order to not change the state of the
        # mocked claim that is passed into the src code for testing
        build(:caregivers_assistance_claim, form: form_data).tap(&:valid?).errors.messages
      end

      before do
        expect(Raven).not_to receive(:tags_context).with(claim_guid: claim.guid)

        expect(described_class::AUDITOR).to receive(:record).with(:submission_attempt)
        expect(described_class::AUDITOR).to receive(:record).with(
          :submission_failure_client_data,
          claim_guid: claim.guid,
          errors: expected_errors
        )
      end
    end

    it 'records caregiver stats' do
      form_data = claim.form
      params = { caregivers_assistance_claim: { form: form_data } }
      expect_any_instance_of(Form1010cg::Auditor).to receive(:record_caregivers)

      post :create, params:
    end

    it 'submits to background job' do
      expect_any_instance_of(Form1010cg::Service).to receive(:assert_veteran_status)
      expect(Form1010cg::SubmissionJob).to receive(:perform_async)
      post :create, params: { caregivers_assistance_claim: { form: claim.form } }

      expect(JSON.parse(response.body)['data']['id']).to eq(SavedClaim::CaregiversAssistanceClaim.last.id.to_s)
    end
  end

  describe '#download_pdf' do
    let(:response_pdf) { Rails.root.join 'tmp', 'pdfs', '10-10CG_from_response.pdf' }
    let(:expected_pdf) { Rails.root.join 'spec', 'fixtures', 'pdf_fill', '10-10CG', 'unsigned', 'simple.pdf' }

    after do
      File.delete(response_pdf) if File.exist?(response_pdf)
    end

    it_behaves_like '10-10CG request with missing param: caregivers_assistance_claim', :download_pdf
    it_behaves_like '10-10CG request with missing param: form', :download_pdf

    it 'generates a filled out 10-10CG and sends file as response', run_at: '2017-07-25 00:00:00 -0400' do
      form_data = get_fixture('pdf_fill/10-10CG/simple').to_json
      params    = { caregivers_assistance_claim: { form: form_data } }
      claim     = build(:caregivers_assistance_claim, form: form_data)

      expect(SavedClaim::CaregiversAssistanceClaim).to receive(:new).with(
        form: form_data
      ).and_return(
        claim
      )

      expect(SecureRandom).to receive(:uuid).and_return('file-name-uuid') # When controller generates it for filename

      expect(described_class::AUDITOR).to receive(:record).with(:pdf_download)

      post(:download_pdf, params:)

      expect(response).to have_http_status(:ok)

      # download response conent (the pdf) to disk
      File.open(response_pdf, 'wb+') { |f| f.write(response.body) }

      # compare it with the pdf fixture
      expect(
        pdfs_fields_match?(response_pdf, expected_pdf)
      ).to eq(true)

      # ensure that the tmp file was deleted
      expect(
        File.exist?('tmp/pdfs/10-10CG_file-name-uuid.pdf')
      ).to eq(false)
    end
  end
end
