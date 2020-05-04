# frozen_string_literal: true

require 'rails_helper'

RSpec.describe V0::CaregiversAssistanceClaimsController, type: :controller do
  it 'inherits from ActionController::API' do
    expect(described_class.ancestors).to include(ActionController::API)
  end

  describe '#create' do
    it 'requires "caregivers_assistance_claim" param' do
      expect(Flipper).to receive(:enabled?).with(:allow_online_10_10cg_submissions).and_return(true)
      expect_any_instance_of(Form1010cg::Service).not_to receive(:submit_claim!)

      post :create, params: {}

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
      expect(Flipper).to receive(:enabled?).with(:allow_online_10_10cg_submissions).and_return(true)
      expect_any_instance_of(Form1010cg::Service).not_to receive(:submit_claim!)

      post :create, params: { caregivers_assistance_claim: { form: nil } }

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

    context 'when Flipper :allow_online_10_10cg_submissions is' do
      context 'disabled' do
        it 'renders :service_unavailable' do
          expect(Flipper).to receive(:enabled?).with(:allow_online_10_10cg_submissions).and_return(false)
          expect_any_instance_of(Form1010cg::Service).not_to receive(:submit_claim!)

          post :create, params: { caregivers_assistance_claim: { form: '{ "my": "data" }' } }

          expect(response).to have_http_status(:service_unavailable)
        end
      end

      context 'enabled' do
        it 'submits claim with Form1010cg::Service' do
          expected = {
            carma_case_id: 'A_123',
            submitted_at: DateTime.now.iso8601,
            form_data: '{ "my": "data" }'
          }

          submission = double(
            carma_case_id: expected[:carma_case_id],
            submitted_at: expected[:submitted_at]
          )

          expect(Flipper).to receive(:enabled?).with(:allow_online_10_10cg_submissions).and_return(true)
          expect_any_instance_of(Form1010cg::Service).to receive(
            :submit_claim!
          ).with(
            form: expected[:form_data]
          ).and_return(
            submission
          )

          post :create, params: { caregivers_assistance_claim: { form: expected[:form_data] } }

          expect(response).to have_http_status(:ok)

          res_body = JSON(response.body)

          expect(res_body['data']).to be_present
          expect(res_body['data']['id']).to eq('')
          expect(res_body['data']['attributes']).to be_present
          expect(res_body['data']['attributes']['confirmation_number']).to eq(expected[:carma_case_id])
          expect(res_body['data']['attributes']['submitted_at']).to eq(expected[:submitted_at])
        end
      end
    end
  end
end
