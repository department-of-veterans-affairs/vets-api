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

  describe 'with an body that does not conform to the schema because it is missing status' do
    it 'responds 400' do
      params = {
        'data' => {
          'type' => 'powerOfAttorneyRequestDecision',
          'attributes' => {
            'declinedReason' => 'Some reason',
            'representative' => {
              'firstName' => 'BEATRICE',
              'lastName' => 'STROUD',
              'email' => 'Beatrice.Stroud44@va.gov'
            }
          }
        }
      }

      mock_ccg(scopes) do
        perform_request(params)
      end

      expect(response).to(
        have_http_status(:bad_request)
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
            'representative' => {
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

      expect(response).to(
        have_http_status(:not_found)
      )

      expect(body).to(
        eq({ 'error' => 'Record not found' })
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
            'representative' => {
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

      expect(response).to(
        have_http_status(:not_found)
      )

      expect(body).to(
        eq({ 'error' => 'Record not found' })
      )
    end
  end

  describe 'with a valid decline with reason submitted twice' do
    let(:id) { '600085312_3853983' }

    it 'responds no_content first and then unprocessable_entity second', run_at: '2024-05-09T07:18:04Z' do
      params = {
        'data' => {
          'type' => 'powerOfAttorneyRequestDecision',
          'attributes' => {
            'status' => 'Declined',
            'declinedReason' => 'Some reason',
            'representative' => {
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
            have_http_status(:no_content)
          )

          body = perform_request(params)

          expect(response).to(
            have_http_status(:unprocessable_entity)
          )

          expect(body).to eq(
            'errors' => [
              {
                'title' => 'Status Transition must be terminating: [New | Pending] -> [Accepted | Declined]',
                'detail' => 'status - Transition must be terminating: [New | Pending] -> [Accepted | Declined]'
              }
            ]
          )
        end
      end
    end
  end

  describe 'status transitions' do
    scenarios = [
      { previous: 'New',      current: 'New',      http_status: :unprocessable_entity },
      { previous: 'New',      current: 'Pending',  http_status: :unprocessable_entity },
      { previous: 'New',      current: 'Accepted', http_status: :no_content           },
      { previous: 'New',      current: 'Declined', http_status: :no_content           },
      { previous: 'Pending',  current: 'New',      http_status: :unprocessable_entity },
      { previous: 'Pending',  current: 'Pending',  http_status: :unprocessable_entity },
      { previous: 'Pending',  current: 'Accepted', http_status: :no_content           },
      { previous: 'Pending',  current: 'Declined', http_status: :no_content           },
      { previous: 'Accepted', current: 'New',      http_status: :unprocessable_entity },
      { previous: 'Accepted', current: 'Pending',  http_status: :unprocessable_entity },
      { previous: 'Accepted', current: 'Accepted', http_status: :unprocessable_entity },
      { previous: 'Accepted', current: 'Declined', http_status: :unprocessable_entity },
      { previous: 'Declined', current: 'New',      http_status: :unprocessable_entity },
      { previous: 'Declined', current: 'Pending',  http_status: :unprocessable_entity },
      { previous: 'Declined', current: 'Accepted', http_status: :unprocessable_entity },
      { previous: 'Declined', current: 'Declined', http_status: :unprocessable_entity }
    ]

    before do
      allow(ClaimsApi::PowerOfAttorneyRequest::Decision).to(
        receive(:create)
      )

      expect(ClaimsApi::PowerOfAttorneyRequest::Decision).to(
        receive(:find).and_return(
          OpenStruct.new(status: previous)
        )
      )
    end

    scenarios.each do |scenario|
      describe "when previous: #{scenario[:previous]}, current: #{scenario[:current]}" do
        let(:previous) { scenario[:previous] }
        let(:current) { scenario[:current] }

        it "returns http status #{scenario[:http_status]}" do
          params = {
            'data' => {
              'type' => 'powerOfAttorneyRequestDecision',
              'attributes' => {
                'status' => current,
                'declinedReason' => nil,
                'representative' => {
                  'firstName' => 'BEATRICE',
                  'lastName' => 'STROUD',
                  'email' => 'Beatrice.Stroud44@va.gov'
                }
              }
            }
          }

          mock_ccg(scopes) do
            perform_request(params)
          end

          expect(response).to(
            have_http_status(scenario[:http_status])
          )
        end
      end
    end
  end
end
