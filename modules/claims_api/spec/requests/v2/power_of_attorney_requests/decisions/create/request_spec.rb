# frozen_string_literal: true

require 'rails_helper'
require Rails.root / 'modules/claims_api/spec/rails_helper'

RSpec.describe 'Power Of Attorney Requests: decisions#create', :bgs, type: :request do
  def perform_request(params)
    post(
      "/services/claims/v2/power-of-attorney-requests/#{id}/decision",
      params: params.to_json,
      headers:
    )

    return if response.body.blank?

    JSON.parse(response.body)
  end

  let(:id) { '1234_5678' }

  let(:headers) do
    {
      'Content-Type' => 'application/json',
      'Accept' => 'application/json'
    }
  end

  let(:scopes) do
    %w[
      system/system/claim.write
      system/claim.read
    ]
  end

  describe 'when a malformed body is posted' do
    let(:params) { '{{{{' }

    it 'something' do
      mock_ccg(scopes) do
        post(
          "/services/claims/v2/power-of-attorney-requests/#{id}/decision",
          params:,
          headers:
        )
      end

      body = JSON.parse(response.body)
      expect(body).to eq(
        'errors' => [
          {
            'title' => 'Bad request',
            'detail' => 'Malformed JSON in request body',
            'code' => '400',
            'status' => '400'
          }
        ]
      )

      expect(response).to(
        have_http_status(:bad_request)
      )
    end
  end

  describe 'with an body that does not conform to the schema because it is missing status' do
    it 'responds 400' do
      params = {
        'data' => {
          'type' => 'powerOfAttorneyRequestDecision',
          'attributes' => {
            'declinedReason' => 'Some reason',
            'createdBy' => {
              'firstName' => 'BEATRICE',
              'lastName' => 'STROUD',
              'email' => 'Beatrice.Stroud44@va.gov'
            }
          }
        }
      }

      body =
        mock_ccg(scopes) do
          perform_request(params)
        end

      expect(body).to eq(
        'errors' => [
          {
            'title' => 'Validation error',
            'detail' => 'object at `/data/attributes` is missing required properties: status',
            'code' => '109',
            'status' => '422'
          }
        ]
      )

      expect(response).to(
        have_http_status(:unprocessable_entity)
      )
    end
  end

  describe 'with a nonexistent participant id in our composite id' do
    let(:id) { '1234_5678' }

    it 'responds 404' do
      params = {
        'data' => {
          'type' => 'powerOfAttorneyRequestDecision',
          'attributes' => {
            'status' => 'Declined',
            'declinedReason' => 'Some reason',
            'createdBy' => {
              'firstName' => 'BEATRICE',
              'lastName' => 'STROUD',
              'email' => 'Beatrice.Stroud44@va.gov'
            }
          }
        }
      }

      body =
        mock_ccg(scopes) do
          use_soap_cassette('nonexistent_participant_id', use_spec_name_prefix: true) do
            perform_request(params)
          end
        end

      expect(body).to eq(
        'errors' => [
          {
            'title' => 'Record not found',
            'detail' => 'The record identified by 1234_5678 could not be found',
            'code' => '404',
            'status' => '404'
          }
        ]
      )

      expect(response).to(
        have_http_status(:not_found)
      )
    end
  end

  describe 'with just a nonexistent proc id in our composite id' do
    let(:id) { '600085312_5678' }

    it 'responds 404' do
      params = {
        'data' => {
          'type' => 'powerOfAttorneyRequestDecision',
          'attributes' => {
            'status' => 'Declined',
            'declinedReason' => 'Some reason',
            'createdBy' => {
              'firstName' => 'BEATRICE',
              'lastName' => 'STROUD',
              'email' => 'Beatrice.Stroud44@va.gov'
            }
          }
        }
      }

      body =
        mock_ccg(scopes) do
          use_soap_cassette('nonexistent_proc_id', use_spec_name_prefix: true) do
            perform_request(params)
          end
        end

      expect(body).to eq(
        'errors' => [
          {
            'title' => 'Record not found',
            'detail' => 'The record identified by 600085312_5678 could not be found',
            'code' => '404',
            'status' => '404'
          }
        ]
      )

      expect(response).to(
        have_http_status(:not_found)
      )
    end
  end

  describe 'with a valid decline with reason submitted twice' do
    let(:id) { '600085312_3853983' }

    it 'responds accepted first and then unprocessable_entity second', run_at: '2024-05-09T07:18:04Z' do
      params = {
        'data' => {
          'type' => 'powerOfAttorneyRequestDecision',
          'attributes' => {
            'status' => 'Declined',
            'declinedReason' => 'Some reason',
            'createdBy' => {
              'firstName' => 'BEATRICE',
              'lastName' => 'STROUD',
              'email' => 'Beatrice.Stroud44@va.gov'
            }
          }
        }
      }

      mock_ccg(scopes, allow_playback_repeats: true) do
        use_soap_cassette('declined_twice', use_spec_name_prefix: true) do
          perform_request(params)

          expect(response).to(
            have_http_status(:accepted)
          )

          body = perform_request(params)

          expect(body).to eq(
            'errors' => [
              {
                'title' => 'must be original',
                'detail' => 'base - must be original',
                'code' => '100',
                'source' => {
                  'pointer' => 'data/attributes/base'
                },
                'status' => '422'
              }
            ]
          )

          expect(response).to(
            have_http_status(:unprocessable_entity)
          )
        end
      end
    end
  end

  describe 'irrelevant declined reason' do
    let(:id) { '600043216_3853237' }

    it 'complains', run_at: '2024-05-09T07:18:04Z' do
      params = {
        'data' => {
          'type' => 'powerOfAttorneyRequestDecision',
          'attributes' => {
            'status' => 'Accepted',
            'declinedReason' => 'Some reason',
            'createdBy' => {
              'firstName' => 'BEATRICE',
              'lastName' => 'STROUD',
              'email' => 'Beatrice.Stroud44@va.gov'
            }
          }
        }
      }

      mock_ccg(scopes, allow_playback_repeats: true) do
        use_soap_cassette('irrelevant_declined_reason', use_spec_name_prefix: true) do
          body = perform_request(params)

          expect(body).to eq(
            'errors' => [
              {
                'title' => 'Declined reason can only accompany a declination',
                'detail' => 'declined-reason - can only accompany a declination',
                'code' => '100',
                'source' => {
                  'pointer' => 'data/attributes/declined-reason'
                },
                'status' => '422'
              }
            ]
          )

          expect(response).to(
            have_http_status(:unprocessable_entity)
          )
        end
      end
    end
  end

  describe 'originality' do
    before do
      allow(ClaimsApi::PowerOfAttorneyRequest::Decision).to(
        receive(:create)
      )

      expect(ClaimsApi::PowerOfAttorneyRequest::Decision).to(
        receive(:find).and_return(
          OpenStruct.new(blank?: blank?)
        )
      )
    end

    let(:params) do
      {
        'data' => {
          'type' => 'powerOfAttorneyRequestDecision',
          'attributes' => {
            'status' => 'Accepted',
            'declinedReason' => nil,
            'createdBy' => {
              'firstName' => 'BEATRICE',
              'lastName' => 'STROUD',
              'email' => 'Beatrice.Stroud44@va.gov'
            }
          }
        }
      }
    end

    describe 'when decision already made' do
      let(:blank?) { false }

      it 'returns http status 422' do
        mock_ccg(scopes) do
          perform_request(params)
        end

        expect(response).to(
          have_http_status(:unprocessable_entity)
        )
      end
    end

    describe 'when decision not already made' do
      let(:blank?) { true }

      it 'returns http status 202' do
        mock_ccg(scopes) do
          perform_request(params)
        end

        expect(response).to(
          have_http_status(:accepted)
        )
      end
    end
  end
end
