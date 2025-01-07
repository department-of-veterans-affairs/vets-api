# frozen_string_literal: true

# rubocop:disable Metrics/ModuleLength
module PoaRequestResponses
  # rubocop:disable Metrics/MethodLength
  def self.pending_poa_response(poa_request, time, expires_at)
    {
      'id' => poa_request.id,
      'claimant_id' => poa_request.claimant_id,
      'created_at' => time,
      'expires_at' => expires_at,
      'power_of_attorney_form' => {
        'authorizations' => {
          'record_disclosure' => true,
          'record_disclosure_limitations' => [],
          'address_change' => true
        },
        'claimant' => {
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
      },
      'resolution' => nil
    }
  end

  def self.poa_response_with_resolution_extra_day(poa_request, time, time_plus_one_day)
    {
      'id' => poa_request.id,
      'claimant_id' => poa_request.claimant_id,
      'created_at' => time,
      'expires_at' => nil,
      'power_of_attorney_form' => {
        'authorizations' => {
          'record_disclosure' => true,
          'record_disclosure_limitations' => [],
          'address_change' => true
        },
        'claimant' => {
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
      },
      'resolution' => {
        'id' => poa_request.resolution.id,
        'type' => 'decision',
        'created_at' => time_plus_one_day,
        'creator_id' => poa_request.resolution.resolving.creator_id,
        'decision_type' => 'acceptance'
      }
    }
  end

  def self.veteran_poa_response_with_extra_day(poa_request, time, time_plus_one_day)
    {
      'id' => poa_request.id,
      'claimant_id' => poa_request.claimant_id,
      'created_at' => time_plus_one_day,
      'expires_at' => nil,
      'power_of_attorney_form' => {
        'authorizations' => {
          'record_disclosure' => true,
          'record_disclosure_limitations' => %w[
            HIV
            DRUG_ABUSE
          ],
          'address_change' => true
        },
        'claimant' => {
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
      },
      'resolution' => {
        'id' => poa_request.resolution.id,
        'type' => 'decision',
        'created_at' => time,
        'creator_id' => poa_request.resolution.resolving.creator_id,
        'decision_type' => 'acceptance'
      }
    }
  end

  def self.veteran_poa_response_with_both_extra_day(poa_request, time_plus_one_day)
    {
      'id' => poa_request.id,
      'claimant_id' => poa_request.claimant_id,
      'created_at' => time_plus_one_day,
      'expires_at' => nil,
      'power_of_attorney_form' => {
        'authorizations' => {
          'record_disclosure' => true,
          'record_disclosure_limitations' => %w[
            HIV
            DRUG_ABUSE
          ],
          'address_change' => true
        },
        'claimant' => {
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
      },
      'resolution' => {
        'id' => poa_request.resolution.id,
        'type' => 'decision',
        'created_at' => time_plus_one_day,
        'creator_id' => poa_request.resolution.resolving.creator_id,
        'decision_type' => 'acceptance'
      }
    }
  end

  def self.accepted_poa_response(poa_request, time)
    {
      'id' => poa_request.id,
      'claimant_id' => poa_request.claimant_id,
      'created_at' => time,
      'expires_at' => nil,
      'power_of_attorney_form' => {
        'authorizations' => {
          'record_disclosure' => true,
          'record_disclosure_limitations' => [],
          'address_change' => true
        },
        'claimant' => {
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
      },
      'resolution' => {
        'id' => poa_request.resolution.id,
        'type' => 'decision',
        'created_at' => time,
        'creator_id' => poa_request.resolution.resolving.creator_id,
        'decision_type' => 'acceptance'
      }
    }
  end

  def self.declined_poa_response(poa_request, time)
    {
      'id' => poa_request.id,
      'claimant_id' => poa_request.claimant_id,
      'created_at' => time,
      'expires_at' => nil,
      'power_of_attorney_form' => {
        'authorizations' => {
          'record_disclosure' => true,
          'record_disclosure_limitations' => [],
          'address_change' => true
        },
        'claimant' => {
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
  end
  # rubocop:enable Metrics/MethodLength
end
# rubocop:enable Metrics/ModuleLength
