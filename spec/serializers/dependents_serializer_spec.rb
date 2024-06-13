# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DependentsSerializer, type: :serializer do
  subject { serialize(dependents, serializer_class: described_class) }

  let(:person) do
    {
      award_indicator: "N",
      date_of_birth: "01/02/1960",
      email_address: "test@email.com",
      first_name: "JANE",
      last_name: "WEBB",
      middle_name: "M",
      ptcpnt_id: "600140899",
      related_to_vet: "Y",
      relationship: "Spouse",
      ssn: "222883214",
      veteran_indicator: "N"
    }
  end
  let(:dependents) do
    {
      number_of_records: "2",
      persons: [person],
      return_code: "SHAR 9999",
      return_message: "Records found"
    }
  end

  let(:data) { JSON.parse(subject)['data'] }
  let(:attributes) { data['attributes'] }

  it 'includes :id' do
    expect(data['id']).to be_blank
  end

  context 'when persons is a hash' do
    let(:persons_hash) do
      {
        number_of_records: "2",
        persons: person,
        return_code: "SHAR 9999",
        return_message: "Records found"
      }
    end
    let(:response_persons_hash) { serialize(persons_hash, serializer_class: described_class) }
    let(:attributes_persons_hash) { JSON.parse(response_persons_hash)['data']['attributes'] }

    it 'includes :persons as an Array' do
      expect(attributes_persons_hash['persons']).to be_kind_of(Array)
      expect(attributes_persons_hash['persons'].size).to eq 1
    end
  end

  context 'when persons is an array' do
    it 'includes :persons' do
      expect(attributes['persons']).to be_kind_of(Array)
      expect(attributes['persons'].size).to eq dependents[:persons].size
    end
  end

  it 'includes person with attributes' do
    expect(attributes['persons'].first).to include(
      "award_indicator" => "N",
      "date_of_birth" => "01/02/1960",
      "email_address" => "test@email.com",
      "first_name" => "JANE",
      "last_name" => "WEBB",
      "middle_name" => "M",
      "ptcpnt_id" => "600140899",
      "related_to_vet" => "Y",
      "relationship" => "Spouse",
      "ssn" => "222883214",
      "veteran_indicator" => "N"
    )
  end
end
