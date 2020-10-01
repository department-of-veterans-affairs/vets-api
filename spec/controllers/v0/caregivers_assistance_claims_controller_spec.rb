# frozen_string_literal: true

require 'rails_helper'

RSpec.describe V0::CaregiversAssistanceClaimsController, type: :controller do
  it 'inherits from ActionController::API' do
    expect(described_class.ancestors).to include(ActionController::API)
  end

  shared_examples '10-10CG request with missing param: caregivers_assistance_claim' do |controller_action|
    before do
      expect_any_instance_of(Form1010cg::Service).not_to receive(:process_claim!)
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
      expect_any_instance_of(Form1010cg::Service).not_to receive(:process_claim!)
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
      expect_any_instance_of(Form1010cg::Service).not_to receive(:process_claim!)
    end

    it 'builds a claim and raises its errors' do
      expect(SavedClaim::CaregiversAssistanceClaim).to receive(:new).with(
        form: form_data
      ).and_return(
        claim
      )

      expect(Form1010cg::Service).not_to receive(:new).with(claim)

      post controller_action, params: params

      res_body = JSON.parse(response.body)

      expect(response.status).to eq(422)

      expect(res_body['errors']).to be_present
      expect(res_body['errors'].size).to eq(2)
      expect(res_body['errors'][0]['title']).to include(
        "did not contain a required property of 'veteran'"
      )
      expect(res_body['errors'][0]['code']).to eq('100')
      expect(res_body['errors'][0]['status']).to eq('422')
      expect(res_body['errors'][1]['title']).to include(
        "did not contain a required property of 'primaryCaregiver'"
      )
      expect(res_body['errors'][1]['code']).to eq('100')
      expect(res_body['errors'][1]['status']).to eq('422')
    end
  end

  describe '#create' do
    it_behaves_like '10-10CG request with missing param: caregivers_assistance_claim', :create do
      before do
        expect(Form1010cg::Auditor.instance).to receive(:record).with(:submission_attempt)
        expect(Form1010cg::Auditor.instance).to receive(:record).with(
          :submission_failure_client_data,
          errors: ['param is missing or the value is empty: caregivers_assistance_claim']
        )
      end
    end

    it_behaves_like '10-10CG request with missing param: form', :create do
      before do
        expect(Form1010cg::Auditor.instance).to receive(:record).with(:submission_attempt)
        expect(Form1010cg::Auditor.instance).to receive(:record).with(
          :submission_failure_client_data,
          errors: ['param is missing or the value is empty: form']
        )
      end
    end

    it_behaves_like '10-10CG request with invalid form data', :create do
      before do
        # Need to build a duplicate claim in order to not change the state of the
        # mocked claim that is passed into the src code for testing
        expected_errors = build(:caregivers_assistance_claim, form: form_data).tap(&:valid?).errors.messages

        expect(Form1010cg::Auditor.instance).to receive(:record).with(:submission_attempt)
        expect(Form1010cg::Auditor.instance).to receive(:record).with(
          :submission_failure_client_data,
          claim_guid: claim.guid,
          errors: expected_errors
        )
      end
    end

    it 'submits claim with Form1010cg::Service' do
      claim = build(:caregivers_assistance_claim)
      form_data = claim.form
      params = { caregivers_assistance_claim: { form: form_data } }
      service = double
      submission = double(
        carma_case_id: 'A_123',
        submitted_at: DateTime.now.iso8601,
        attachments: :attachments_uploaded,
        metadata: :metadata_submitted
      )

      expect(SavedClaim::CaregiversAssistanceClaim).to receive(:new).with(
        form: form_data
      ).and_return(
        claim
      )

      expect(Form1010cg::Service).to receive(:new).with(claim).and_return(service)
      expect(service).to receive(:process_claim!).and_return(submission)

      expect(Form1010cg::Auditor.instance).to receive(:record).with(:submission_attempt)
      expect(Form1010cg::Auditor.instance).to receive(:record).with(
        :submission_success,
        claim_guid: claim.guid,
        carma_case_id: submission.carma_case_id,
        attachments: submission.attachments,
        metadata: submission.metadata
      )

      post :create, params: params

      expect(response).to have_http_status(:ok)

      res_body = JSON.parse(response.body)

      expect(res_body['data']).to be_present
      expect(res_body['data']['id']).to eq('')
      expect(res_body['data']['attributes']).to be_present
      expect(res_body['data']['attributes']['confirmation_number']).to eq(submission.carma_case_id)
      expect(res_body['data']['attributes']['submitted_at']).to eq(submission.submitted_at)
    end

    context 'when Form1010cg::Service raises InvalidVeteranStatus' do
      it 'renders backend service outage' do
        claim         = build(:caregivers_assistance_claim)
        form_data     = claim.form
        params        = { caregivers_assistance_claim: { form: form_data } }
        service       = double

        expect(SavedClaim::CaregiversAssistanceClaim).to receive(:new).with(
          form: form_data
        ).and_return(
          claim
        )

        expect(Form1010cg::Service).to receive(:new).with(claim).and_return(service)
        expect(service).to receive(:process_claim!).and_raise(Form1010cg::Service::InvalidVeteranStatus)

        expect(Form1010cg::Auditor.instance).to receive(:record).with(:submission_attempt)
        expect(Form1010cg::Auditor.instance).to receive(:record).with(
          :submission_failure_client_qualification,
          claim_guid: claim.guid,
          veteran_name: claim.veteran_data['fullName']
        )

        post :create, params: params

        expect(response.status).to eq(503)
        expect(
          JSON.parse(
            response.body
          )
        ).to eq(
          'errors' => [
            {
              'title' => 'Service unavailable',
              'detail' => 'Backend Service Outage',
              'code' => '503',
              'status' => '503'
            }
          ]
        )
      end

      it 'matches the response of a Common::Client::Errors::ClientError' do
        claim = build(:caregivers_assistance_claim)
        form_data = claim.form
        params = { caregivers_assistance_claim: { form: form_data } }
        service = double

        ## Backend Client Error Scenario

        expect(SavedClaim::CaregiversAssistanceClaim).to receive(:new).with(
          form: form_data
        ).and_return(
          claim
        )

        expect(Form1010cg::Service).to receive(:new).with(claim).and_return(service)
        expect(service).to receive(:process_claim!).and_raise(Common::Client::Errors::ClientError)

        backend_client_error_response = post :create, params: params

        ## Invalid Veteran Status Scenario

        expect(SavedClaim::CaregiversAssistanceClaim).to receive(:new).with(
          form: form_data
        ).and_return(
          claim
        )

        expect(Form1010cg::Service).to receive(:new).with(claim).and_return(service)
        expect(service).to receive(:process_claim!).and_raise(Form1010cg::Service::InvalidVeteranStatus)

        expect(Form1010cg::Auditor.instance).to receive(:record).with(:submission_attempt)
        expect(Form1010cg::Auditor.instance).to receive(:record).with(
          :submission_failure_client_qualification,
          claim_guid: claim.guid,
          veteran_name: claim.veteran_data['fullName']
        )

        invalid_veteran_status_response = post :create, params: params

        %w[status body headers].each do |response_attr|
          expect(
            invalid_veteran_status_response.send(response_attr)
          ).to eq(
            backend_client_error_response.send(response_attr)
          )
        end
      end
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
    it_behaves_like '10-10CG request with invalid form data', :download_pdf

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
      expect(Form1010cg::Auditor.instance).to receive(:record).with(:pdf_download)

      post :download_pdf, params: params

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
