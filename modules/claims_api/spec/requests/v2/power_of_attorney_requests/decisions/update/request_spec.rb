# frozen_string_literal: true

require 'rails_helper'
require Rails.root / 'modules/claims_api/spec/rails_helper'

RSpec.describe 'Power Of Attorney Requests: decisions#update', :bgs, type: :request do
  cassette_directory =
    Pathname.new(
      # This mirrors the path to this spec file. It could be convenient to keep
      # that in sync in case this file moves.
      'claims_api/requests/v2/power_of_attorney_requests/decisions/update/request_spec'
    )

  def perform_request(params)
    put(
      "/services/claims/v2/power-of-attorney-requests/#{id}/decision",
      params: params.to_json,
      headers:
    )
  end

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

  describe 'with a valid decline with reason submitted twice and then third time nonterminal' do
    let(:id) { '600085312_3853983' }

    it 'responds no_content first and then bad_request second', run_at: '2024-05-09T07:18:04Z' do
      params = {
        'decision' => {
          'status' => 'Declined',
          'declinedReason' => 'Some reason',
          'representative' => {
            'firstName' => 'BEATRICE',
            'lastName' => 'STROUD',
            'email' => 'Beatrice.Stroud44@va.gov'
          }
        }
      }

      mock_ccg(scopes, allow_playback_repeats: true) do
        use_soap_cassette(cassette_directory / 'repeated_terminal_and_nonterminal_submissions') do
          perform_request(params)

          expect(response).to(
            have_http_status(:no_content)
          )

          perform_request(params)

          expect(response).to(
            have_http_status(:no_content)
          )

          params['decision']['status'] = 'Accepted'
          perform_request(params)

          expect(response).to(
            have_http_status(:bad_request)
          )
        end
      end
    end
  end

  describe 'status transitions' do
    scenarios = [
      { previous: 'New',      current: 'New',      http_status: :no_content  },
      { previous: 'New',      current: 'Pending',  http_status: :no_content  },
      { previous: 'New',      current: 'Accepted', http_status: :no_content  },
      { previous: 'New',      current: 'Declined', http_status: :no_content  },
      { previous: 'Pending',  current: 'New',      http_status: :no_content  },
      { previous: 'Pending',  current: 'Pending',  http_status: :no_content  },
      { previous: 'Pending',  current: 'Accepted', http_status: :no_content  },
      { previous: 'Pending',  current: 'Declined', http_status: :no_content  },
      { previous: 'Accepted', current: 'New',      http_status: :bad_request },
      { previous: 'Accepted', current: 'Pending',  http_status: :bad_request },
      { previous: 'Accepted', current: 'Accepted', http_status: :no_content  },
      { previous: 'Accepted', current: 'Declined', http_status: :bad_request },
      { previous: 'Declined', current: 'New',      http_status: :bad_request },
      { previous: 'Declined', current: 'Pending',  http_status: :bad_request },
      { previous: 'Declined', current: 'Accepted', http_status: :bad_request },
      { previous: 'Declined', current: 'Declined', http_status: :no_content  }
    ]

    before do
      allow(ClaimsApi::PowerOfAttorneyRequest::Decision).to(
        receive(:update)
      )

      expect(ClaimsApi::PowerOfAttorneyRequest::Decision).to(
        receive(:find).and_return(
          OpenStruct.new(status: previous)
        )
      )
    end

    let(:id) { 'anything' }

    scenarios.each do |scenario|
      describe "when previous: #{scenario[:previous]}, current: #{scenario[:current]}" do
        let(:previous) { scenario[:previous] }
        let(:current) { scenario[:current] }

        it "returns http status #{scenario[:http_status]}" do
          mock_ccg(scopes) do
            params = {
              'decision' => {
                'status' => current,
                'declinedReason' => nil,
                'representative' => {
                  'firstName' => 'BEATRICE',
                  'lastName' => 'STROUD',
                  'email' => 'Beatrice.Stroud44@va.gov'
                }
              }
            }

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
