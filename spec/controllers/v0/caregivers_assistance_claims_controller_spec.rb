# frozen_string_literal: true

require 'rails_helper'

shared_examples 'invalid 10-10CG form submission' do |controller_action, expected_stat_increments = []|
  before do
    expected_stat_increments.each do |stat|
      expect(StatsD).to receive(:increment).with(stat)
    end
  end

  it 'requires "caregivers_assistance_claim" param' do
    expect_any_instance_of(Form1010cg::Service).not_to receive(:process_claim!)

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

  it 'requires "caregivers_assistance_claim.form" param' do
    expect_any_instance_of(Form1010cg::Service).not_to receive(:process_claim!)

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

  it 'builds a claim and raises it\'s errors' do
    params = { caregivers_assistance_claim: { form: '{}' } }
    form_data = params[:caregivers_assistance_claim][:form]
    claim = build(:caregivers_assistance_claim, form: form_data)

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
    expect(res_body['errors'][0]['title']).to include("did not contain a required property of 'veteran'")
    expect(res_body['errors'][0]['code']).to eq('100')
    expect(res_body['errors'][0]['status']).to eq('422')
    expect(res_body['errors'][1]['title']).to include(
      "did not contain a required property of 'primaryCaregiver'"
    )
    expect(res_body['errors'][1]['code']).to eq('100')
    expect(res_body['errors'][1]['status']).to eq('422')
  end
end

RSpec.describe V0::CaregiversAssistanceClaimsController, type: :controller do
  it 'inherits from ActionController::API' do
    expect(described_class.ancestors).to include(ActionController::API)
  end

  describe '#create' do
    context 'when Flipper :allow_online_10_10cg_submissions is' do
      context 'disabled' do
        it 'renders :service_unavailable' do
          expect(Flipper).to receive(:enabled?).with(:allow_online_10_10cg_submissions).and_return(false)
          expect_any_instance_of(Form1010cg::Service).not_to receive(:process_claim!)

          expect(StatsD).to receive(:increment).with('api.form1010cg.submission.attempt')

          post :create, params: { caregivers_assistance_claim: { form: '{ "my": "data" }' } }

          expect(response).to have_http_status(:service_unavailable)
          expect(response.body).to eq(' ')
        end
      end

      context 'enabled' do
        before do
          expect(Flipper).to receive(:enabled?).with(:allow_online_10_10cg_submissions).and_return(true)
        end

        it_behaves_like 'invalid 10-10CG form submission', :create, [
          'api.form1010cg.submission.attempt',
          'api.form1010cg.submission.failure.client.data'
        ]

        it 'submits claim with Form1010cg::Service' do
          claim = build(:caregivers_assistance_claim)
          form_data = claim.form
          params = { caregivers_assistance_claim: { form: form_data } }
          service = double
          submission = double(carma_case_id: 'A_123', submitted_at: DateTime.now.iso8601)

          expect(SavedClaim::CaregiversAssistanceClaim).to receive(:new).with(
            form: form_data
          ).and_return(
            claim
          )

          expect(Form1010cg::Service).to receive(:new).with(claim).and_return(service)
          expect(service).to receive(:process_claim!).and_return(submission)

          expect(StatsD).to receive(:increment).with('api.form1010cg.submission.attempt')
          expect(StatsD).to receive(:increment).with('api.form1010cg.submission.success')

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
            claim = build(:caregivers_assistance_claim)
            form_data = claim.form
            params = { caregivers_assistance_claim: { form: form_data } }
            service = double

            expect(SavedClaim::CaregiversAssistanceClaim).to receive(:new).with(
              form: form_data
            ).and_return(
              claim
            )

            expect(Form1010cg::Service).to receive(:new).with(claim).and_return(service)
            expect(service).to receive(:process_claim!).and_raise(Form1010cg::Service::InvalidVeteranStatus)

            expect(StatsD).to receive(:increment).with('api.form1010cg.submission.attempt')
            expect(StatsD).to receive(:increment).with('api.form1010cg.submission.failure.client.qualification')

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

            expect(Flipper).to receive(:enabled?).with(:allow_online_10_10cg_submissions).and_return(true)

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

            expect(StatsD).to receive(:increment).with('api.form1010cg.submission.attempt')
            expect(StatsD).to receive(:increment).with('api.form1010cg.submission.failure.client.qualification')

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
    end
  end

  describe '#download_pdf' do
    let(:response_pdf) { Rails.root.join 'tmp', 'pdfs', '10-10CG_from_response.pdf' }
    let(:expected_pdf) { Rails.root.join 'spec', 'fixtures', 'pdf_fill', '10-10CG', 'simple.pdf' }

    after do
      File.delete(response_pdf) if File.exist?(response_pdf)
    end

    it_behaves_like 'invalid 10-10CG form submission', :download_pdf

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
      expect(StatsD).to receive(:increment).with('api.form1010cg.pdf_download')

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
