# frozen_string_literal: true

require 'rails_helper'
require Rails.root / 'modules/claims_api/spec/rails_helper'

RSpec.describe 'Power Of Attorney Requests: index', :bgs, type: :request do
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
      system/claim.write
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

  describe 'with every param invalid in almost all ways' do
    let(:params) do
      # These params with `nil` values are generated from this query string:
      #   `?filter[decision][statuses][]=NotAStatus&sort[field]&sort[order]&page[size]=whoops&page[number]`
      {
        'filter' => {
          'decision' => {
            'statuses' => [
              'NotAStatus'
            ]
          }
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

      expect(subject.body).to eq(
        'errors' => [
          {
            'title' => 'Validation error',
            'detail' => {
              'errors' => {
                'filter' => {
                  'poaCodes' => [
                    'is missing',
                    'must be an array'
                  ],
                  'decision' => {
                    'statuses' => {
                      '0' => [
                        'must be one of: None, Accepted, Declined'
                      ]
                    }
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
                    'must be one of: createdAt'
                  ],
                  'order' => [
                    'must be a string',
                    'must be one of: asc, desc'
                  ]
                }
              },
              'params' => params
            },
            'code' => '109',
            'status' => '422'
          }
        ]
      )

      expect(subject.response).to(
        have_http_status(:unprocessable_entity)
      )
    end
  end

  describe 'with a blank poaCode string value' do
    let(:params) do
      {
        'filter' => {
          'poaCodes' => [
            ''
          ]
        }
      }
    end

    it 'explains that it is bad request' do
      mock_ccg(scopes) do
        subject
      end

      expect(subject.body).to eq(
        'errors' => [
          {
            'title' => 'Validation error',
            'detail' => {
              'errors' => {
                'filter' => {
                  'poaCodes' => {
                    '0' => [
                      'must be filled'
                    ]
                  }
                }
              },
              'params' => params
            },
            'code' => '109',
            'status' => '422'
          }
        ]
      )

      expect(subject.response).to(
        have_http_status(:unprocessable_entity)
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
        use_soap_cassette('minimal_parameter_set', use_spec_name_prefix: true) do
          subject
        end
      end

      expect(subject.body['metadata']).to eq(
        'totalCount' => 4,
        'query' => {
          'filter' => {
            'poaCodes' => [
              '083'
            ],
            'decision' => {
              'statuses' => %w[
                None
                Accepted
                Declined
              ]
            }
          },
          'page' => {
            'size' => 25,
            'number' => 1
          },
          'sort' => {
            'field' => 'createdAt',
            'order' => 'desc'
          }
        }
      )

      expect(subject.response).to(
        have_http_status(:ok)
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
          'decision' => {
            'statuses' => %w[
              Accepted
              Declined
            ]
          }
        },
        'page' => {
          'number' => 2,
          'size' => 5
        },
        'sort' => {
          'field' => 'createdAt',
          'order' => 'asc'
        }
      }
    end

    it 'returns one of a few pages in a decently filtered total result' do
      mock_ccg(scopes) do
        use_soap_cassette('healthy_parameter_set', use_spec_name_prefix: true) do
          subject
        end
      end

      expect(subject.body['data'].first).to eq(
        'id' => '600061742_3854197',
        'type' => 'powerOfAttorneyRequest',
        'attributes' => {
          'powerOfAttorneyCode' => '074',
          'createdAt' => '2024-03-08T13:56:37Z',
          'isAddressChangingAuthorized' => true,
          'isTreatmentDisclosureAuthorized' => true,
          'veteran' => {
            'firstName' => 'WESLEY',
            'middleName' => 'WATSON',
            'lastName' => 'FORD'
          },
          'claimant' => nil,
          'decision' => {
            'status' => 'Accepted',
            'declinedReason' => nil,
            'createdAt' => '2024-03-08T14:10:41Z',
            'createdBy' => {
              'firstName' => 'BEATRICE',
              'lastName' => 'STROUD',
              'email' => 'Beatrice.Stroud44@va.gov'
            }
          },
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

      expect(subject.body['data'].size).to(
        eq(5)
      )

      expect(subject.response).to(
        have_http_status(:ok)
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
        use_soap_cassette('lots_of_records', use_spec_name_prefix: true) do
          subject
        end
      end

      expect(subject.body['data'].size).to(
        eq(100)
      )

      expect(subject.response).to(
        have_http_status(:ok)
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
          'decision' => {
            'statuses' => [
              'Declined'
            ]
          }
        }
      }
    end

    # Unfortunately we can't distinguish between 'valid' and 'invalid' empty
    # results.
    it 'returns an empty result set' do
      mock_ccg(scopes) do
        use_soap_cassette('valid_empty_result', use_spec_name_prefix: true) do
          subject
        end
      end

      expect(subject.body).to eq(
        'metadata' => {
          'totalCount' => 0,
          'query' => {
            'filter' => {
              'poaCodes' => [
                'BQX'
              ],
              'decision' => {
                'statuses' => [
                  'Declined'
                ]
              }
            },
            'page' => {
              'size' => 25,
              'number' => 1
            },
            'sort' => {
              'field' => 'createdAt',
              'order' => 'desc'
            }
          }
        },
        'data' => []
      )

      expect(subject.response).to(
        have_http_status(:ok)
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
        use_soap_cassette('valid_empty_result_from_high_page_number', use_spec_name_prefix: true) do
          subject
        end
      end

      expect(subject.body).to eq(
        'metadata' => {
          'totalCount' => 0,
          'query' => {
            'filter' => {
              'poaCodes' => [
                'BQX'
              ],
              'decision' => {
                'statuses' => %w[
                  None
                  Accepted
                  Declined
                ]
              }
            },
            'page' => {
              'size' => 100,
              'number' => 100
            },
            'sort' => {
              'field' => 'createdAt',
              'order' => 'desc'
            }
          }
        },
        'data' => []
      )

      expect(subject.response).to(
        have_http_status(:ok)
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
        use_soap_cassette('nonexistent_poa_code', use_spec_name_prefix: true) do
          subject
        end
      end

      expect(subject.body).to eq(
        'metadata' => {
          'totalCount' => 0,
          'query' => {
            'filter' => {
              'poaCodes' => [
                'ZZZ'
              ],
              'decision' => {
                'statuses' => %w[
                  None
                  Accepted
                  Declined
                ]
              }
            },
            'page' => {
              'size' => 25,
              'number' => 1
            },
            'sort' => {
              'field' => 'createdAt',
              'order' => 'desc'
            }
          }
        },
        'data' => []
      )

      expect(subject.response).to(
        have_http_status(:ok)
      )
    end
  end

  describe 'bgs client error handling' do
    describe 'from a weird bgs fault' do
      it 'returns a bad gateway error with a fault message' do
        mock_ccg(scopes) do
          use_soap_cassette('weird_bgs_fault', use_spec_name_prefix: true) do
            subject
          end
        end

        expect(subject.body).to eq(
          'errors' => [
            {
              'title' => 'Bad Gateway',
              'detail' => 'Bad Gateway'
            }
          ]
        )

        expect(subject.response).to(
          have_http_status(:bad_gateway)
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

          expect(subject.body).to eq(
            'errors' => [
              {
                'title' => 'Bad Gateway',
                'detail' => 'Bad Gateway'
              }
            ]
          )

          expect(subject.response).to(
            have_http_status(:bad_gateway)
          )
        end
      end

      describe Faraday::SSLError do
        it 'returns a bad gateway error' do
          mock_ccg(scopes) do
            subject
          end

          expect(subject.body).to eq(
            'errors' => [
              {
                'title' => 'Bad Gateway',
                'detail' => 'Bad Gateway'
              }
            ]
          )

          expect(subject.response).to(
            have_http_status(:bad_gateway)
          )
        end
      end

      describe Faraday::TimeoutError do
        it 'returns a bad gateway error' do
          mock_ccg(scopes) do
            subject
          end

          expect(subject.body).to eq(
            'errors' => [
              {
                'title' => 'Gateway timeout',
                'detail' => 'Did not receive a timely response from an upstream server'
              }
            ]
          )

          expect(subject.response).to(
            have_http_status(:gateway_timeout)
          )
        end
      end
    end
  end
end
