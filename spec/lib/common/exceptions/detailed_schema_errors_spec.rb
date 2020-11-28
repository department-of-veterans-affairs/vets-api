# frozen_string_literal: true

require 'spec_helper'
require 'common/exceptions/detailed_schema_errors'

describe Common::Exceptions::DetailedSchemaErrors do
  include FixtureHelpers

  subject do
    described_class.new(@validator.validate(data).to_a).errors.first
  end

  before(:all) do
    schema = get_fixture 'json/detailed_schema_errors_schema'
    @validator = JSONSchemer.schema(schema)
  end

  let(:data) do
    { 'name' => 'Dom N. Ated',
      'age' => 30,
      'married' => false,
      'email' => 'domn@ed.com',
      'gender' => 'male',
      'location' => { 'latitude' => 38.9013369,
                      'longitude' => -77.0316181 },
      'requiredField' => 'exists' }
  end
  let(:pointer) { subject[:source][:pointer] }

  context 'universal data' do
    before { data['gender'] = Faker::Lorem.sentence }

    it 'has a path to the data that failed validation' do
      expect(pointer).to eq '/gender'
    end

    it 'has JSON API ErrorObject fields' do
      expect(subject.to_hash.keys).to match_array %i[code detail meta source status title]
    end
  end

  context 'required fields' do
    before do
      data.delete 'requiredField'
      data.delete 'age'
    end

    it { expect(pointer).to eq '/' }
    it { expect(subject[:title]).to eq 'Missing required fields' }
    it { expect(subject[:meta][:missing_fields]).to match_array %w[requiredField age] }
  end

  context 'data types' do
    it 'respects boolean datatype' do
      data['married'] = 'true'
      expect(subject[:title]).to eq 'Invalid data type'
      expect(subject[:detail]).to eq 'Expected boolean data'
    end

    it 'respects integer datatype' do
      data['age'] = 25.75
      expect(subject[:title]).to eq 'Invalid data type'
      expect(subject[:detail]).to eq 'Expected integer data'
    end

    it 'respects number datatype' do
      data['location']['longitude'] = '123.45'
      expect(pointer).to eq '/location/longitude'
      expect(subject[:title]).to eq 'Invalid data type'
      expect(subject[:detail]).to eq 'Expected number data'
    end

    it 'respects string datatype' do
      data['name'] = 123
      expect(subject[:title]).to eq 'Invalid data type'
      expect(subject[:detail]).to eq 'Expected string data'
    end
  end

  context 'enums' do
    let(:bad_val) { Faker::Lorem.sentence }

    it 'has title, detail, and meta' do
      data['gender'] = bad_val
      expect(subject[:title]).to eq 'Invalid option'
      expect(subject[:detail]).to eq "'#{bad_val}' is not an available option"
      expect(subject[:meta][:available_options]).to match_array %w[male female undisclosed]
    end
  end

  context 'patterns' do
    let(:bad_val) { Faker::Lorem.sentence }

    it 'has title, detail, and meta' do
      data['email'] = bad_val
      expect(subject[:title]).to eq 'Invalid format'
      expect(subject[:detail]).to eq "'#{bad_val}' did not match the defined format"
      expect(subject[:meta][:regex]).to eq '.@.'
    end
  end

  context 'restraints' do
    it 'respects maximum length' do
      data['name'] = Faker::Lorem.sentence(word_count: 20)
      expect(subject[:title]).to eq 'Invalid length'
      expect(subject[:meta]).to eq({ max_length: 20, min_length: 3 })
    end

    it 'respects minimum length' do
      data['name'] = 'Ed'
      expect(subject[:title]).to eq 'Invalid length'
      expect(subject[:meta]).to eq({ max_length: 20, min_length: 3 })
    end

    it 'respects maximum value' do
      data['age'] = 150
      expect(subject[:title]).to eq 'Value outside range'
      expect(subject[:meta]).to eq({ maximum: 130, minimum: 21 })
    end

    it 'respects minimum value' do
      data['age'] = 18
      expect(subject[:title]).to eq 'Value outside range'
      expect(subject[:meta]).to eq({ maximum: 130, minimum: 21 })
    end
  end

  context 'extra data' do
    before { data[:not_in_schema] = Faker::Lorem.sentence }

    it 'points to problem source' do
      expect(pointer).to eq '/not_in_schema'
    end

    it 'has title and detail' do
      expect(subject[:title]).to eq 'Schema mismatch'
      expect(subject[:detail]).to eq 'Unknown data provided'
    end
  end
end
