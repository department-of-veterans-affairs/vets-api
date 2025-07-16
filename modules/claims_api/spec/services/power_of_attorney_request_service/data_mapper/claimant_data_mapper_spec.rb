# frozen_string_literal: true

require 'rails_helper'

describe ClaimsApi::PowerOfAttorneyRequestService::DataMapper::ClaimantDataMapper do
  subject { described_class.new(claimant: claimant_double) }

  let(:mpi_double) do
    double(birls_id: '123456789')
  end

  let(:claimant_double) do
    double(
      first_name: 'John',
      last_name: 'Doe',
      birls_id: nil,
      ssn: '123456789',
      birth_date: Date.new(1970, 1, 1),
      mpi: mpi_double
    )
  end

  let(:expected_response) do
    {
<<<<<<< HEAD
      'name' => 'John Doe',
      'ssn' => '123456789',
      'file_number' => '123456789',
      'date_of_birth' => Date.new(1970, 1, 1)
=======
      name: 'John Doe',
      ssn: '123456789',
      file_number: '123456789',
      date_of_birth: Date.new(1970, 1, 1)
>>>>>>> 0f0617637b (Tests veteran and claimant objects matching real records)
    }
  end

  before do
    subject.instance_variable_set(:@claimant, claimant_double)
  end

  it 'maps the claimant values correctly' do
    expect(subject.call).to eq(expected_response)
  end
end
