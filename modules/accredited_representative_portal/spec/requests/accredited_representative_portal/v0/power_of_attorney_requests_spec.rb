# frozen_string_literal: true

require_relative '../../../rails_helper'

RSpec.describe AccreditedRepresentativePortal::V0::PowerOfAttorneyRequestsController, type: :request do
  let(:test_user) { create(:representative_user) }
  let(:poa_request) { create(:power_of_attorney_request_resolution, :declination).power_of_attorney_request }
  let(:time) { '2024-12-21T04:45:37.458Z' }
  let(:time_plus_one_day ) { '2024-12-22T04:45:37.458Z' }

  let(:poa_requests) do
    [].tap do |memo|
      memo << create(:power_of_attorney_request)
      memo << create(:power_of_attorney_request_resolution, :acceptance).power_of_attorney_request
      memo << create(:power_of_attorney_request_resolution, :acceptance, created_at: time_plus_one_day).power_of_attorney_request
      memo << create(:power_of_attorney_request_resolution, :declination).power_of_attorney_request
      memo << create(:power_of_attorney_request_resolution, :expiration).power_of_attorney_request
    end
  end

  before do
    Flipper.enable(:accredited_representative_portal_pilot)
    login_as(test_user)
    travel_to(time)
  end

  describe 'GET /accredited_representative_portal/v0/power_of_attorney_requests' do
    it 'returns the list of power of attorney requests and defaults to status pending' do
      poa_requests

      get('/accredited_representative_portal/v0/power_of_attorney_requests')

      parsed_response = JSON.parse(response.body)
      expect(response).to have_http_status(:ok)

      expect(parsed_response).to eq(
        [
          {
            'id' => poa_requests[0].id,
            'claimant_id' => poa_requests[0].claimant_id,
            'claimant_type' => 'dependent',
            'created_at' => time,
            'power_of_attorney_form' => {
              'authorizations' => {
                'record_disclosure' => true,
                'record_disclosure_limitations' => [],
                'address_change' => true
              },
              'dependent' => {
                'name' => {
                  'first' => 'John',
                  'middle' => 'Middle',
                  'last' => 'Doe'
                },
                'address' => {
                  'address_line1' => '123 Main St',
                  'address_line2' => 'Apt 1',
                  'city' => 'Springfield',
                  'state_code' => 'IL',
                  'country' => 'US',
                  'zip_code' => '62704',
                  'zip_code_suffix' => '6789'
                },
                'date_of_birth' => '1980-12-31',
                'relationship' => 'Spouse',
                'phone' => '1234567890',
                'email' => 'veteran@example.com'
              },
              'veteran' => {
                'name' => {
                  'first' => 'John',
                  'middle' => 'Middle',
                  'last' => 'Doe'
                },
                'address' => {
                  'address_line1' => '123 Main St',
                  'address_line2' => 'Apt 1',
                  'city' => 'Springfield',
                  'state_code' => 'IL',
                  'country' => 'US',
                  'zip_code' => '62704',
                  'zip_code_suffix' => '6789'
                },
                'ssn' => '123456789',
                'va_file_number' => '123456789',
                'date_of_birth' => '1980-12-31',
                'service_number' => '123456789',
                'service_branch' => 'ARMY',
                'phone' => '1234567890',
                'email' => 'veteran@example.com'
              }
            },
            'power_of_attorney_holder' => {
              'id' => poa_requests[0].power_of_attorney_holder.id,
              'type' => 'veteran_service_organization',
              'name' => poa_requests[0].power_of_attorney_holder.name
            },
            'accredited_individual' => {
              'id' => poa_requests[0].accredited_individual.id,
              'full_name' => [
                poa_requests[0].accredited_individual.first_name,
                poa_requests[0].accredited_individual.last_name
              ].join(' ')
            },
            'resolution' => nil
          }
        ]
      )
    end

    it "returns the list of accepted power of attorney requests and orders them correctly by poa_request.created_at" do
      poa_requests

      poa_requests[1].created_at = time_plus_one_day
      poa_requests[1].save

      get '/accredited_representative_portal/v0/power_of_attorney_requests', params: {"status": "Accepted"}

      parsed_response = JSON.parse(response.body)
      expect(response).to have_http_status(:ok)

      expect(parsed_response).to eq(
        [
          {
            'id' => poa_requests[1].id,
            'claimant_id' => poa_requests[1].claimant_id,
            'claimant_type' => 'dependent',
            'created_at' => time_plus_one_day,
            'power_of_attorney_form' => {
              'authorizations' => {
                'record_disclosure' => true,
                'record_disclosure_limitations' => [],
                'address_change' => true
              },
              'dependent' => {
                'name' => {
                  'first' => 'John',
                  'middle' => 'Middle',
                  'last' => 'Doe'
                },
                'address' => {
                  'address_line1' => '123 Main St',
                  'address_line2' => 'Apt 1',
                  'city' => 'Springfield',
                  'state_code' => 'IL',
                  'country' => 'US',
                  'zip_code' => '62704',
                  'zip_code_suffix' => '6789'
                },
                'date_of_birth' => '1980-12-31',
                'relationship' => 'Spouse',
                'phone' => '1234567890',
                'email' => 'veteran@example.com'
              },
              'veteran' => {
                'name' => {
                  'first' => 'John',
                  'middle' => 'Middle',
                  'last' => 'Doe'
                },
                'address' => {
                  'address_line1' => '123 Main St',
                  'address_line2' => 'Apt 1',
                  'city' => 'Springfield',
                  'state_code' => 'IL',
                  'country' => 'US',
                  'zip_code' => '62704',
                  'zip_code_suffix' => '6789'
                },
                'ssn' => '123456789',
                'va_file_number' => '123456789',
                'date_of_birth' => '1980-12-31',
                'service_number' => '123456789',
                'service_branch' => 'ARMY',
                'phone' => '1234567890',
                'email' => 'veteran@example.com'
              }
            },
            'power_of_attorney_holder' => {
              'id' => poa_requests[1].power_of_attorney_holder.id,
              'type' => 'veteran_service_organization',
              'name' => poa_requests[1].power_of_attorney_holder.name
            },
            'accredited_individual' => {
              'id' => poa_requests[1].accredited_individual.id,
              'full_name' => [
                poa_requests[1].accredited_individual.first_name,
                poa_requests[1].accredited_individual.last_name
              ].join(' ')
            },
            'resolution' => {
              'id' => poa_requests[1].resolution.id,
              'type' => 'decision',
              'created_at' => time,
              'creator_id' => poa_requests[1].resolution.resolving.creator_id,
              'decision_type' => 'acceptance'
            }
          },
          {
            'id' => poa_requests[2].id,
            'claimant_id' => poa_requests[2].claimant_id,
            'claimant_type' => 'dependent',
            'created_at' => time,
            'power_of_attorney_form' => {
              'authorizations' => {
                'record_disclosure' => true,
                'record_disclosure_limitations' => [],
                'address_change' => true
              },
              'dependent' => {
                'name' => {
                  'first' => 'John',
                  'middle' => 'Middle',
                  'last' => 'Doe'
                },
                'address' => {
                  'address_line1' => '123 Main St',
                  'address_line2' => 'Apt 1',
                  'city' => 'Springfield',
                  'state_code' => 'IL',
                  'country' => 'US',
                  'zip_code' => '62704',
                  'zip_code_suffix' => '6789'
                },
                'date_of_birth' => '1980-12-31',
                'relationship' => 'Spouse',
                'phone' => '1234567890',
                'email' => 'veteran@example.com'
              },
              'veteran' => {
                'name' => {
                  'first' => 'John',
                  'middle' => 'Middle',
                  'last' => 'Doe'
                },
                'address' => {
                  'address_line1' => '123 Main St',
                  'address_line2' => 'Apt 1',
                  'city' => 'Springfield',
                  'state_code' => 'IL',
                  'country' => 'US',
                  'zip_code' => '62704',
                  'zip_code_suffix' => '6789'
                },
                'ssn' => '123456789',
                'va_file_number' => '123456789',
                'date_of_birth' => '1980-12-31',
                'service_number' => '123456789',
                'service_branch' => 'ARMY',
                'phone' => '1234567890',
                'email' => 'veteran@example.com'
              }
            },
            'power_of_attorney_holder' => {
              'id' => poa_requests[2].power_of_attorney_holder.id,
              'type' => 'veteran_service_organization',
              'name' => poa_requests[2].power_of_attorney_holder.name
            },
            'accredited_individual' => {
              'id' => poa_requests[2].accredited_individual.id,
              'full_name' => [
                poa_requests[2].accredited_individual.first_name,
                poa_requests[2].accredited_individual.last_name
              ].join(' ')
            },
            'resolution' => {
              'id' => poa_requests[2].resolution.id,
              'type' => 'decision',
              'created_at' => time_plus_one_day,
              'creator_id' => poa_requests[2].resolution.resolving.creator_id,
              'decision_type' => 'acceptance'
            }
          }
        ]
      )
    end

    it "returns the list of accepted power of attorney requests and orders them correctly by resolution.created_at" do
      poa_requests

      get '/accredited_representative_portal/v0/power_of_attorney_requests', params: {"status": "Accepted", "sort_field": "resolution.created_at", "sort_direction": "asc"}

      parsed_response = JSON.parse(response.body)
      expect(response).to have_http_status(:ok)

      expect(parsed_response).to eq(
        [
          {
            'id' => poa_requests[1].id,
            'claimant_id' => poa_requests[1].claimant_id,
            'claimant_type' => 'dependent',
            'created_at' => time,
            'power_of_attorney_form' => {
              'authorizations' => {
                'record_disclosure' => true,
                'record_disclosure_limitations' => [],
                'address_change' => true
              },
              'dependent' => {
                'name' => {
                  'first' => 'John',
                  'middle' => 'Middle',
                  'last' => 'Doe'
                },
                'address' => {
                  'address_line1' => '123 Main St',
                  'address_line2' => 'Apt 1',
                  'city' => 'Springfield',
                  'state_code' => 'IL',
                  'country' => 'US',
                  'zip_code' => '62704',
                  'zip_code_suffix' => '6789'
                },
                'date_of_birth' => '1980-12-31',
                'relationship' => 'Spouse',
                'phone' => '1234567890',
                'email' => 'veteran@example.com'
              },
              'veteran' => {
                'name' => {
                  'first' => 'John',
                  'middle' => 'Middle',
                  'last' => 'Doe'
                },
                'address' => {
                  'address_line1' => '123 Main St',
                  'address_line2' => 'Apt 1',
                  'city' => 'Springfield',
                  'state_code' => 'IL',
                  'country' => 'US',
                  'zip_code' => '62704',
                  'zip_code_suffix' => '6789'
                },
                'ssn' => '123456789',
                'va_file_number' => '123456789',
                'date_of_birth' => '1980-12-31',
                'service_number' => '123456789',
                'service_branch' => 'ARMY',
                'phone' => '1234567890',
                'email' => 'veteran@example.com'
              }
            },
            'power_of_attorney_holder' => {
              'id' => poa_requests[1].power_of_attorney_holder.id,
              'type' => 'veteran_service_organization',
              'name' => poa_requests[1].power_of_attorney_holder.name
            },
            'accredited_individual' => {
              'id' => poa_requests[1].accredited_individual.id,
              'full_name' => [
                poa_requests[1].accredited_individual.first_name,
                poa_requests[1].accredited_individual.last_name
              ].join(' ')
            },
            'resolution' => {
              'id' => poa_requests[1].resolution.id,
              'type' => 'decision',
              'created_at' => time,
              'creator_id' => poa_requests[1].resolution.resolving.creator_id,
              'decision_type' => 'acceptance'
            }
          },
          {
            'id' => poa_requests[2].id,
            'claimant_id' => poa_requests[2].claimant_id,
            'claimant_type' => 'dependent',
            'created_at' => time,
            'power_of_attorney_form' => {
              'authorizations' => {
                'record_disclosure' => true,
                'record_disclosure_limitations' => [],
                'address_change' => true
              },
              'dependent' => {
                'name' => {
                  'first' => 'John',
                  'middle' => 'Middle',
                  'last' => 'Doe'
                },
                'address' => {
                  'address_line1' => '123 Main St',
                  'address_line2' => 'Apt 1',
                  'city' => 'Springfield',
                  'state_code' => 'IL',
                  'country' => 'US',
                  'zip_code' => '62704',
                  'zip_code_suffix' => '6789'
                },
                'date_of_birth' => '1980-12-31',
                'relationship' => 'Spouse',
                'phone' => '1234567890',
                'email' => 'veteran@example.com'
              },
              'veteran' => {
                'name' => {
                  'first' => 'John',
                  'middle' => 'Middle',
                  'last' => 'Doe'
                },
                'address' => {
                  'address_line1' => '123 Main St',
                  'address_line2' => 'Apt 1',
                  'city' => 'Springfield',
                  'state_code' => 'IL',
                  'country' => 'US',
                  'zip_code' => '62704',
                  'zip_code_suffix' => '6789'
                },
                'ssn' => '123456789',
                'va_file_number' => '123456789',
                'date_of_birth' => '1980-12-31',
                'service_number' => '123456789',
                'service_branch' => 'ARMY',
                'phone' => '1234567890',
                'email' => 'veteran@example.com'
              }
            },
            'power_of_attorney_holder' => {
              'id' => poa_requests[2].power_of_attorney_holder.id,
              'type' => 'veteran_service_organization',
              'name' => poa_requests[2].power_of_attorney_holder.name
            },
            'accredited_individual' => {
              'id' => poa_requests[2].accredited_individual.id,
              'full_name' => [
                poa_requests[2].accredited_individual.first_name,
                poa_requests[2].accredited_individual.last_name
              ].join(' ')
            },
            'resolution' => {
              'id' => poa_requests[2].resolution.id,
              'type' => 'decision',
              'created_at' => time_plus_one_day,
              'creator_id' => poa_requests[2].resolution.resolving.creator_id,
              'decision_type' => 'acceptance'
            }
          }
        ]
      )
    end

    it "returns the list of accepted power of attorney requests and orders them correctly by resolution.created_at desc" do
      poa_requests

      get '/accredited_representative_portal/v0/power_of_attorney_requests', params: {"status": "Accepted", "sort_field": "resolution.created_at"}

      parsed_response = JSON.parse(response.body)
      expect(response).to have_http_status(:ok)

      expect(parsed_response).to eq(
        [
          {
            'id' => poa_requests[2].id,
            'claimant_id' => poa_requests[2].claimant_id,
            'claimant_type' => 'dependent',
            'created_at' => time,
            'power_of_attorney_form' => {
              'authorizations' => {
                'record_disclosure' => true,
                'record_disclosure_limitations' => [],
                'address_change' => true
              },
              'dependent' => {
                'name' => {
                  'first' => 'John',
                  'middle' => 'Middle',
                  'last' => 'Doe'
                },
                'address' => {
                  'address_line1' => '123 Main St',
                  'address_line2' => 'Apt 1',
                  'city' => 'Springfield',
                  'state_code' => 'IL',
                  'country' => 'US',
                  'zip_code' => '62704',
                  'zip_code_suffix' => '6789'
                },
                'date_of_birth' => '1980-12-31',
                'relationship' => 'Spouse',
                'phone' => '1234567890',
                'email' => 'veteran@example.com'
              },
              'veteran' => {
                'name' => {
                  'first' => 'John',
                  'middle' => 'Middle',
                  'last' => 'Doe'
                },
                'address' => {
                  'address_line1' => '123 Main St',
                  'address_line2' => 'Apt 1',
                  'city' => 'Springfield',
                  'state_code' => 'IL',
                  'country' => 'US',
                  'zip_code' => '62704',
                  'zip_code_suffix' => '6789'
                },
                'ssn' => '123456789',
                'va_file_number' => '123456789',
                'date_of_birth' => '1980-12-31',
                'service_number' => '123456789',
                'service_branch' => 'ARMY',
                'phone' => '1234567890',
                'email' => 'veteran@example.com'
              }
            },
            'power_of_attorney_holder' => {
              'id' => poa_requests[2].power_of_attorney_holder.id,
              'type' => 'veteran_service_organization',
              'name' => poa_requests[2].power_of_attorney_holder.name
            },
            'accredited_individual' => {
              'id' => poa_requests[2].accredited_individual.id,
              'full_name' => [
                poa_requests[2].accredited_individual.first_name,
                poa_requests[2].accredited_individual.last_name
              ].join(' ')
            },
            'resolution' => {
              'id' => poa_requests[2].resolution.id,
              'type' => 'decision',
              'created_at' => time_plus_one_day,
              'creator_id' => poa_requests[2].resolution.resolving.creator_id,
              'decision_type' => 'acceptance'
            }
          },
          {
            'id' => poa_requests[1].id,
            'claimant_id' => poa_requests[1].claimant_id,
            'claimant_type' => 'dependent',
            'created_at' => time,
            'power_of_attorney_form' => {
              'authorizations' => {
                'record_disclosure' => true,
                'record_disclosure_limitations' => [],
                'address_change' => true
              },
              'dependent' => {
                'name' => {
                  'first' => 'John',
                  'middle' => 'Middle',
                  'last' => 'Doe'
                },
                'address' => {
                  'address_line1' => '123 Main St',
                  'address_line2' => 'Apt 1',
                  'city' => 'Springfield',
                  'state_code' => 'IL',
                  'country' => 'US',
                  'zip_code' => '62704',
                  'zip_code_suffix' => '6789'
                },
                'date_of_birth' => '1980-12-31',
                'relationship' => 'Spouse',
                'phone' => '1234567890',
                'email' => 'veteran@example.com'
              },
              'veteran' => {
                'name' => {
                  'first' => 'John',
                  'middle' => 'Middle',
                  'last' => 'Doe'
                },
                'address' => {
                  'address_line1' => '123 Main St',
                  'address_line2' => 'Apt 1',
                  'city' => 'Springfield',
                  'state_code' => 'IL',
                  'country' => 'US',
                  'zip_code' => '62704',
                  'zip_code_suffix' => '6789'
                },
                'ssn' => '123456789',
                'va_file_number' => '123456789',
                'date_of_birth' => '1980-12-31',
                'service_number' => '123456789',
                'service_branch' => 'ARMY',
                'phone' => '1234567890',
                'email' => 'veteran@example.com'
              }
            },
            'power_of_attorney_holder' => {
              'id' => poa_requests[1].power_of_attorney_holder.id,
              'type' => 'veteran_service_organization',
              'name' => poa_requests[1].power_of_attorney_holder.name
            },
            'accredited_individual' => {
              'id' => poa_requests[1].accredited_individual.id,
              'full_name' => [
                poa_requests[1].accredited_individual.first_name,
                poa_requests[1].accredited_individual.last_name
              ].join(' ')
            },
            'resolution' => {
              'id' => poa_requests[1].resolution.id,
              'type' => 'decision',
              'created_at' => time,
              'creator_id' => poa_requests[1].resolution.resolving.creator_id,
              'decision_type' => 'acceptance'
            }
          }
        ]
      )
    end

    it "returns paginated results" do
      poa_requests

      get '/accredited_representative_portal/v0/power_of_attorney_requests', params: {"status": "Accepted", "sort_field": "resolution.created_at", page_size: 1}

      parsed_response = JSON.parse(response.body)
      expect(response).to have_http_status(:ok)

      expect(parsed_response).to eq(
          [{
            'id' => poa_requests[2].id,
            'claimant_id' => poa_requests[2].claimant_id,
            'claimant_type' => 'dependent',
            'created_at' => time,
            'power_of_attorney_form' => {
              'authorizations' => {
                'record_disclosure' => true,
                'record_disclosure_limitations' => [],
                'address_change' => true
              },
              'dependent' => {
                'name' => {
                  'first' => 'John',
                  'middle' => 'Middle',
                  'last' => 'Doe'
                },
                'address' => {
                  'address_line1' => '123 Main St',
                  'address_line2' => 'Apt 1',
                  'city' => 'Springfield',
                  'state_code' => 'IL',
                  'country' => 'US',
                  'zip_code' => '62704',
                  'zip_code_suffix' => '6789'
                },
                'date_of_birth' => '1980-12-31',
                'relationship' => 'Spouse',
                'phone' => '1234567890',
                'email' => 'veteran@example.com'
              },
              'veteran' => {
                'name' => {
                  'first' => 'John',
                  'middle' => 'Middle',
                  'last' => 'Doe'
                },
                'address' => {
                  'address_line1' => '123 Main St',
                  'address_line2' => 'Apt 1',
                  'city' => 'Springfield',
                  'state_code' => 'IL',
                  'country' => 'US',
                  'zip_code' => '62704',
                  'zip_code_suffix' => '6789'
                },
                'ssn' => '123456789',
                'va_file_number' => '123456789',
                'date_of_birth' => '1980-12-31',
                'service_number' => '123456789',
                'service_branch' => 'ARMY',
                'phone' => '1234567890',
                'email' => 'veteran@example.com'
              }
            },
            'power_of_attorney_holder' => {
              'id' => poa_requests[2].power_of_attorney_holder.id,
              'type' => 'veteran_service_organization',
              'name' => poa_requests[2].power_of_attorney_holder.name
            },
            'accredited_individual' => {
              'id' => poa_requests[2].accredited_individual.id,
              'full_name' => [
                poa_requests[2].accredited_individual.first_name,
                poa_requests[2].accredited_individual.last_name
              ].join(' ')
            },
            'resolution' => {
              'id' => poa_requests[2].resolution.id,
              'type' => 'decision',
              'created_at' => time_plus_one_day,
              'creator_id' => poa_requests[2].resolution.resolving.creator_id,
              'decision_type' => 'acceptance'
            }
          }]
      )

    end

    it "returns an error when status is not valid" do
      get '/accredited_representative_portal/v0/power_of_attorney_requests', params: {"status": "Not Real"}

      expect(response).to have_http_status(:bad_request)
      parsed_response = JSON.parse(response.body)

      expect(parsed_response).to eq(
        {
          "errors"=>{
            "status"=>[
              "must be one of: Pending, Accepted, Declined"
            ]
          }
        }
      )
    end
  end

  describe 'GET /accredited_representative_portal/v0/power_of_attorney_requests/:id' do
    it 'returns the details of a specific power of attorney request' do
      get("/accredited_representative_portal/v0/power_of_attorney_requests/#{poa_request.id}")

      parsed_response = JSON.parse(response.body)
      expect(response).to have_http_status(:ok)

      expect(parsed_response).to eq(
        {
          'id' => poa_request.id,
          'claimant_id' => poa_request.claimant_id,
          'claimant_type' => 'dependent',
          'created_at' => time,
          'power_of_attorney_form' => {
            'authorizations' => {
              'record_disclosure' => true,
              'record_disclosure_limitations' => [],
              'address_change' => true
            },
            'dependent' => {
              'name' => {
                'first' => 'John',
                'middle' => 'Middle',
                'last' => 'Doe'
              },
              'address' => {
                'address_line1' => '123 Main St',
                'address_line2' => 'Apt 1',
                'city' => 'Springfield',
                'state_code' => 'IL',
                'country' => 'US',
                'zip_code' => '62704',
                'zip_code_suffix' => '6789'
              },
              'date_of_birth' => '1980-12-31',
              'relationship' => 'Spouse',
              'phone' => '1234567890',
              'email' => 'veteran@example.com'
            },
            'veteran' => {
              'name' => {
                'first' => 'John',
                'middle' => 'Middle',
                'last' => 'Doe'
              },
              'address' => {
                'address_line1' => '123 Main St',
                'address_line2' => 'Apt 1',
                'city' => 'Springfield',
                'state_code' => 'IL',
                'country' => 'US',
                'zip_code' => '62704',
                'zip_code_suffix' => '6789'
              },
              'ssn' => '123456789',
              'va_file_number' => '123456789',
              'date_of_birth' => '1980-12-31',
              'service_number' => '123456789',
              'service_branch' => 'ARMY',
              'phone' => '1234567890',
              'email' => 'veteran@example.com'
            }
          },
          'resolution' => {
            'id' => poa_request.resolution.id,
            'type' => 'decision',
            'created_at' => time,
            'creator_id' => poa_request.resolution.resolving.creator_id,
            'reason' => 'Didn\'t authorize treatment record disclosure',
            'decision_type' => 'declination'
          },
          'power_of_attorney_holder' => {
            'id' => poa_request.power_of_attorney_holder.id,
            'type' => 'veteran_service_organization',
            'name' => poa_request.power_of_attorney_holder.name
          },
          'accredited_individual' => {
            'id' => poa_request.accredited_individual.id,
            'full_name' => [
              poa_request.accredited_individual.first_name,
              poa_request.accredited_individual.last_name
            ].join(' ')
          }
        }
      )
    end
  end
end
