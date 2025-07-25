# frozen_string_literal: true

require 'rails_helper'

describe ClaimsApi::PowerOfAttorneyRequestService::DataMapper::VeteranDataMapper do
  subject { described_class.new(veteran: veteran_double) }

  let(:veteran_double) do
    double(
      first_name: 'John',
      last_name: 'Doe',
      ssn: '123456789',
      birls_id: '123456789',
      birth_date: Date.new(1970, 1, 1)
    )
  end

  let(:expected_response) do
    {
      'name' => 'John Doe',
      'ssn' => '123456789',
      'file_number' => '123456789',
      'date_of_birth' => Date.new(1970, 1, 1)
    }
  end

  before do
    subject.instance_variable_set(:@veteran, veteran_double)
  end

  it 'maps the veteran values correctly' do
    expect(subject.call).to eq(expected_response)
  end
end
