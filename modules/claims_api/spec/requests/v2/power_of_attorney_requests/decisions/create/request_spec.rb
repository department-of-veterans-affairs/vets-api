# frozen_string_literal: true

require 'rails_helper'
require Rails.root / 'modules/claims_api/spec/rails_helper'

# TODO: Delete this file
# We are covered by request_controller_spec.rb
RSpec.describe 'ClaimsApi::V2::PowerOfAttorneyRequests::Decisions#create', :bgs, :skip, type: :request do
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
      system/claim.write
      system/claim.read
    ]
  end

  describe 'with no ccg' do
    it 'returns unauthorized' do
      body = perform_request({})

      expect(body).to eq(
        'errors' => [
          {
            'title' => 'Not authorized',
            'detail' => 'Not authorized'
          }
        ]
      )

      expect(response).to(
        have_http_status(:unauthorized)
      )
    end
  end

  describe 'from underlying faraday connection issues' do
    let(:params) do
      {
        'data' => {
          'type' => 'powerOfAttorneyRequestDecision',
          'attributes' => {
            'status' => 'declining',
            'decliningReason' => 'Some reason',
            'createdBy' => {
              'firstName' => 'BEATRICE',
              'lastName' => 'STROUD',
              'email' => 'Beatrice.Stroud44@va.gov'
            }
          }
        }
      }
    end

    before do
      pattern = %r{/VDC/VeteranRepresentativeService}
      stub_request(:post, pattern).to_raise(
        described_class
      )
    end

    describe Faraday::ConnectionFailed do
      it 'returns a bad gateway error' do
        body =
          mock_ccg(scopes) do
            perform_request(params)
          end

        expect(body).to eq(
          'errors' => [
            {
              'title' => 'Bad Gateway',
              'detail' => 'Bad Gateway'
            }
          ]
        )

        expect(response).to(
          have_http_status(:bad_gateway)
        )
      end
    end

    describe Faraday::SSLError do
      it 'returns a bad gateway error' do
        body =
          mock_ccg(scopes) do
            perform_request(params)
          end

        expect(body).to eq(
          'errors' => [
            {
              'title' => 'Bad Gateway',
              'detail' => 'Bad Gateway'
            }
          ]
        )

        expect(response).to(
          have_http_status(:bad_gateway)
        )
      end
    end

    describe Faraday::TimeoutError do
      it 'returns a bad gateway error' do
        body =
          mock_ccg(scopes) do
            perform_request(params)
          end

        expect(body).to eq(
          'errors' => [
            {
              'title' => 'Gateway timeout',
              'detail' => 'Did not receive a timely response from an upstream server'
            }
          ]
        )

        expect(response).to(
          have_http_status(:gateway_timeout)
        )
      end
    end
  end

  describe 'when a malformed body is posted' do
    it 'responds 400' do
      mock_ccg(scopes) do
        post(
          "/services/claims/v2/power-of-attorney-requests/#{id}/decision",
          params: '{{{{',
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
            'decliningReason' => 'Some reason',
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
            'status' => 'declining',
            'decliningReason' => 'Some reason',
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
            'status' => 'declining',
            'decliningReason' => 'Some reason',
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

  describe 'against an obsolete poa request' do
    let(:id) { '600043216_42665' }

    it 'responds 422' do
      params = {
        'data' => {
          'type' => 'powerOfAttorneyRequestDecision',
          'attributes' => {
            'status' => 'declining',
            'decliningReason' => 'Some reason',
            'createdBy' => {
              'firstName' => 'BEATRICE',
              'lastName' => 'STROUD',
              'email' => 'Beatrice.Stroud44@va.gov'
            }
          }
        }
      }

      mock_ccg(scopes, allow_playback_repeats: true) do
        use_soap_cassette('obsolete', use_spec_name_prefix: true) do
          body = perform_request(params)

          expect(body).to eq(
            'errors' => [
              {
                'title' => 'Power of attorney request must not be obsolete',
                'detail' => 'power-of-attorney-request - must not be obsolete',
                'code' => '100',
                'source' => {
                  'pointer' => 'data/attributes/power-of-attorney-request'
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

  describe 'with a valid decline with reason submitted twice' do
    let(:id) { '600043216_73930' }

    it 'responds accepted first and then unprocessable_entity second', run_at: '2024-05-09T07:18:04Z' do
      params = {
        'data' => {
          'type' => 'powerOfAttorneyRequestDecision',
          'attributes' => {
            'status' => 'declining',
            'decliningReason' => 'Some reason',
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
            'status' => 'accepting',
            'decliningReason' => 'Some reason',
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
                'title' => 'Declining reason can only accompany a declination',
                'detail' => 'declining-reason - can only accompany a declination',
                'code' => '100',
                'source' => {
                  'pointer' => 'data/attributes/declining-reason'
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

  describe 'valid acceptance' do
    let(:id) { '600036161_74840' }

    it 'succeeds', run_at: '2024-05-09T07:18:04Z' do
      params = {
        'data' => {
          'type' => 'powerOfAttorneyRequestDecision',
          'attributes' => {
            'status' => 'accepting',
            'decliningReason' => nil,
            'createdBy' => {
              'firstName' => 'BEATRICE',
              'lastName' => 'STROUD',
              'email' => 'Beatrice.Stroud44@va.gov'
            }
          }
        }
      }

      mock_ccg(scopes, allow_playback_repeats: true) do
        use_soap_cassette('acceptance', use_spec_name_prefix: true) do
          perform_request(params)

          expect(response).to(
            have_http_status(:accepted)
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

      expect(ClaimsApi::PowerOfAttorneyRequest).to(
        receive(:find).and_return(
          OpenStruct.new(
            decision_status:,
            obsolete: false
          )
        )
      )
    end

    let(:params) do
      {
        'data' => {
          'type' => 'powerOfAttorneyRequestDecision',
          'attributes' => {
            'status' => 'accepting',
            'decliningReason' => nil,
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
      let(:decision_status) { 'accepting' }

      it 'returns http status 422' do
        body =
          mock_ccg(scopes) do
            perform_request(params)
          end

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

    describe 'when decision not already made' do
      let(:decision_status) { nil }

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

  describe 'obsolescence' do
    before do
      allow(ClaimsApi::PowerOfAttorneyRequest::Decision).to(
        receive(:create)
      )

      expect(ClaimsApi::PowerOfAttorneyRequest).to(
        receive(:find).and_return(
          OpenStruct.new(
            decision_status: nil,
            obsolete:
          )
        )
      )
    end

    let(:params) do
      {
        'data' => {
          'type' => 'powerOfAttorneyRequestDecision',
          'attributes' => {
            'status' => 'accepting',
            'decliningReason' => nil,
            'createdBy' => {
              'firstName' => 'BEATRICE',
              'lastName' => 'STROUD',
              'email' => 'Beatrice.Stroud44@va.gov'
            }
          }
        }
      }
    end

    describe 'when not obsolete' do
      let(:obsolete) { false }

      it 'returns http status 202' do
        mock_ccg(scopes) do
          perform_request(params)
        end

        expect(response).to(
          have_http_status(:accepted)
        )
      end
    end

    describe 'when obsolete' do
      let(:obsolete) { true }

      it 'returns http status 422' do
        body =
          mock_ccg(scopes) do
            perform_request(params)
          end

        expect(body).to eq(
          'errors' => [
            {
              'title' => 'Power of attorney request must not be obsolete',
              'detail' => 'power-of-attorney-request - must not be obsolete',
              'code' => '100',
              'source' => {
                'pointer' => 'data/attributes/power-of-attorney-request'
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
