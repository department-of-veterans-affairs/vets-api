# frozen_string_literal: true

require 'rails_helper'
require Rails.root / 'modules/claims_api/spec/rails_helper'

RSpec.describe 'Power Of Attorney Requests: index', :bgs, type: :request do
  cassette_directory =
    Pathname.new(
      # This mirrors the path to this spec file. It could be convenient to keep
      # that in sync in case this file moves.
      'claims_api/requests/v2/power_of_attorney_requests/index/request_spec'
    )

  subject do
    get(
      '/services/claims/v2/power-of-attorney-requests',
      headers:,
      params:
    )

    OpenStruct.new(
      body: JSON.parse(response.body),
      response:
    )
  end

  let(:headers) do
    {
      'Accept' => 'application/json'
    }
  end

  let(:scopes) do
    %w[
      system/system/claim.write
      system/claim.read
    ]
  end

  let(:params) do
    {
      'filter' => {
        'poaCodes' => [
          'ZZZ'
        ]
      }
    }
  end

  describe 'with no ccg' do
    it 'returns unauthorized' do
      expect(subject.response).to(
        have_http_status(:unauthorized)
      )
    end
  end

  describe 'with every param invalid' do
    let(:params) do
      # These params with `nil` values are generated from this query string:
      #   `?filter[statuses][]=NotAStatus&sort[field]&sort[order]&page[size]=whoops&page[number]`
      {
        'filter' => {
          'statuses' => [
            'NotAStatus'
          ]
        },
        'sort' => {
          'field' => nil,
          'order' => nil
        },
        'page' => {
          'size' => 'whoops',
          'number' => nil
        }
      }
    end

    it 'returns bad request with every invalidity detail' do
      mock_ccg(scopes) do
        subject
      end

      expect(subject.response).to(
        have_http_status(:bad_request)
      )

      expect(subject.body).to eq(
        'errors' => [
          {
            'title' => 'Bad request',
            'detail' => {
              'errors' => {
                'filter' => {
                  'poaCodes' => [
                    'is missing',
                    'must be an array'
                  ],
                  'statuses' => {
                    '0' => [
                      'must be one of: New, Pending, Accepted, Declined'
                    ]
                  }
                },
                'page' => {
                  'size' => [
                    'must be an integer',
                    'must be greater than or equal to 1',
                    'must be less than or equal to 100'
                  ],
                  'number' => [
                    'must be an integer',
                    'must be greater than or equal to 1'
                  ]
                },
                'sort' => {
                  'field' => [
                    'must be a string',
                    'must be one of: submittedAt'
                  ],
                  'order' => [
                    'must be a string',
                    'must be one of: asc, desc'
                  ]
                }
              },
              'params' => {
                'filter' => {
                  'statuses' => [
                    'NotAStatus'
                  ]
                },
                'page' => {
                  'size' => 'whoops',
                  'number' => nil
                },
                'sort' => {
                  'field' => nil,
                  'order' => nil
                }
              }
            }
          }
        ]
      )
    end
  end

  describe 'with a minimal parameter set' do
    let(:params) do
      {
        'filter' => {
          'poaCodes' => [
            '083'
          ]
        }
      }
    end

    it 'returns metadata including defaulted parameters and a total count' do
      mock_ccg(scopes) do
        use_soap_cassette(cassette_directory / 'minimal_parameter_set') do
          subject
        end
      end

      expect(subject.response).to(
        have_http_status(:ok)
      )

      expect(subject.body['metadata']).to eq(
        'totalCount' => 4,
        'query' => {
          'filter' => {
            'poaCodes' => [
              '083'
            ],
            'statuses' => %w[
              New
              Pending
              Accepted
              Declined
            ]
          },
          'page' => {
            'size' => 25,
            'number' => 1
          },
          'sort' => {
            'field' => 'submittedAt',
            'order' => 'desc'
          }
        }
      )
    end
  end

  # Just wanted to see some different flavors.
  describe 'with a healthy mixture of params' do
    let(:params) do
      {
        'filter' => {
          'poaCodes' => %w[
            083 002 003 065 074 022 091 070
            097 077 1EY 6B6 862 9U7 BQX
          ],
          'statuses' => %w[
            Accepted
            Declined
          ]
        },
        'page' => {
          'number' => 2,
          'size' => 5
        },
        'sort' => {
          'field' => 'submittedAt',
          'order' => 'asc'
        }
      }
    end

    it 'returns one of a few pages in a decently filtered total result' do
      mock_ccg(scopes) do
        use_soap_cassette(cassette_directory / 'healthy_parameter_set') do
          subject
        end
      end

      expect(subject.response).to(
        have_http_status(:ok)
      )

      expect(subject.body['data'].size).to(
        eq(5)
      )

      expect(subject.body['data'].first).to eq(
        'id' => 3_854_197,
        'type' => 'powerOfAttorneyRequest',
        'attributes' => {
          'status' => 'Accepted',
          'declinedReason' => nil,
          'powerOfAttorneyCode' => '074',
          'submittedAt' => '2024-03-08T13:56:37Z',
          'acceptedOrDeclinedAt' => '2024-03-08T14:10:41Z',
          'isAddressChangingAuthorized' => true,
          'isTreatmentDisclosureAuthorized' => true,
          'veteran' => {
            'firstName' => 'WESLEY',
            'middleName' => 'WATSON',
            'lastName' => 'FORD',
            'participantId' => 600_061_742
          },
          'representative' => {
            'firstName' => 'BEATRICE',
            'lastName' => 'STROUD',
            'email' => 'Beatrice.Stroud44@va.gov'
          },
          'claimant' => nil,
          'claimantAddress' => {
            'city' => 'WASHINGTON',
            'state' => 'DC',
            'zip' => '20420',
            'country' => 'USA',
            'militaryPostOffice' => nil,
            'militaryPostalCode' => nil
          }
        }
      )
    end
  end

  describe 'when looking for lots of records with a very permissive query' do
    let(:params) do
      {
        'filter' => {
          'poaCodes' => %w[
            083 002 003 065 074 022 091 070
            097 077 1EY 6B6 862 9U7 BQX
          ]
        },
        'page' => {
          'size' => 100
        }
      }
    end

    it 'returns bgs max page size of 100' do
      mock_ccg(scopes) do
        use_soap_cassette(cassette_directory / 'lots_of_records') do
          subject
        end
      end

      expect(subject.response).to(
        have_http_status(:ok)
      )

      expect(subject.body['data'].size).to(
        eq(100)
      )
    end
  end

  describe 'with a combo of real poa code and status that has no results' do
    let(:params) do
      {
        'filter' => {
          'poaCodes' => [
            'BQX'
          ],
          'statuses' => [
            'Declined'
          ]
        }
      }
    end

    # Unfortunately we can't distinguish between 'valid' and 'invalid' empty
    # results.
    it 'returns an empty result set' do
      mock_ccg(scopes) do
        use_soap_cassette(cassette_directory / 'valid_empty_result') do
          subject
        end
      end

      expect(subject.response).to(
        have_http_status(:ok)
      )

      expect(subject.body).to eq(
        'metadata' => {
          'totalCount' => 0,
          'query' => {
            'filter' => {
              'poaCodes' => [
                'BQX'
              ],
              'statuses' => [
                'Declined'
              ]
            },
            'page' => {
              'size' => 25,
              'number' => 1
            },
            'sort' => {
              'field' => 'submittedAt',
              'order' => 'desc'
            }
          }
        },
        'data' => []
      )
    end
  end

  describe 'with a high enough page number that has no results' do
    let(:params) do
      {
        'filter' => {
          'poaCodes' => [
            'BQX'
          ]
        },
        'page' => {
          # Also checked against `{'size'=>1,'number'=>1}` to confirm they do
          # have records.
          'size' => 100,
          'number' => 100
        }
      }
    end

    # Unfortunately we can't distinguish between 'valid' and 'invalid' empty
    # results.
    it 'returns an empty result set' do
      mock_ccg(scopes) do
        use_soap_cassette(cassette_directory / 'valid_empty_result_from_high_page_number') do
          subject
        end
      end

      expect(subject.response).to(
        have_http_status(:ok)
      )

      expect(subject.body).to eq(
        'metadata' => {
          'totalCount' => 0,
          'query' => {
            'filter' => {
              'poaCodes' => [
                'BQX'
              ],
              'statuses' => %w[
                New
                Pending
                Accepted
                Declined
              ]
            },
            'page' => {
              'size' => 100,
              'number' => 100
            },
            'sort' => {
              'field' => 'submittedAt',
              'order' => 'desc'
            }
          }
        },
        'data' => []
      )
    end
  end

  describe 'with a non existent poa code' do
    let(:params) do
      {
        'filter' => {
          'poaCodes' => [
            'ZZZ'
          ]
        }
      }
    end

    # Unfortunately we can't distinguish between 'valid' and 'invalid' empty
    # results.
    it 'returns an empty result set' do
      mock_ccg(scopes) do
        use_soap_cassette(cassette_directory / 'nonexistent_poa_code') do
          subject
        end
      end

      expect(subject.response).to(
        have_http_status(:ok)
      )

      expect(subject.body).to eq(
        'metadata' => {
          'totalCount' => 0,
          'query' => {
            'filter' => {
              'poaCodes' => [
                'ZZZ'
              ],
              'statuses' => %w[
                New
                Pending
                Accepted
                Declined
              ]
            },
            'page' => {
              'size' => 25,
              'number' => 1
            },
            'sort' => {
              'field' => 'submittedAt',
              'order' => 'desc'
            }
          }
        },
        'data' => []
      )
    end
  end

  describe 'bgs client error handling' do
    describe 'from a weird bgs fault' do
      it 'returns a bad gateway error with a fault message' do
        mock_ccg(scopes) do
          use_soap_cassette(cassette_directory / 'weird_bgs_fault') do
            subject
          end
        end

        expect(subject.response).to(
          have_http_status(:bad_gateway)
        )

        expect(subject.body).to eq(
          'errors' => [
            {
              'title' => 'Bad Gateway',
              'detail' => 'Weird BGFS Fault'
            }
          ]
        )
      end
    end

    describe 'from underlying faraday connection issues' do
      before do
        pattern = %r{/VDC/ManageRepresentativeService}
        stub_request(:post, pattern).to_raise(
          described_class
        )
      end

      describe Faraday::ConnectionFailed do
        it 'returns a bad gateway error' do
          mock_ccg(scopes) do
            subject
          end

          expect(subject.response).to(
            have_http_status(:bad_gateway)
          )

          expect(subject.body).to eq(
            'errors' => [
              {
                'title' => 'Bad Gateway',
                'detail' => 'Exception from WebMock'
              }
            ]
          )
        end
      end

      describe Faraday::SSLError do
        it 'returns a bad gateway error' do
          mock_ccg(scopes) do
            subject
          end

          expect(subject.response).to(
            have_http_status(:bad_gateway)
          )

          expect(subject.body).to eq(
            'errors' => [
              {
                'title' => 'Bad Gateway',
                'detail' => 'Exception from WebMock'
              }
            ]
          )
        end
      end

      describe Faraday::TimeoutError do
        it 'returns a bad gateway error' do
          mock_ccg(scopes) do
            subject
          end

          expect(subject.response).to(
            have_http_status(:gateway_timeout)
          )

          expect(subject.body).to eq(
            'errors' => [
              {
                'title' => 'Gateway timeout',
                'detail' => 'Did not receive a timely response from an upstream server'
              }
            ]
          )
        end
      end
    end
  end
end
