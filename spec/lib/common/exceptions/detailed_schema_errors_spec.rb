# frozen_string_literal: true

require 'rails_helper'
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

  after(:all) do
    schema = get_fixture 'json/detailed_schema_errors_schema'
    @validator = JSONSchemer.schema(schema)
  end

  let(:data) do
    { 'name' => 'Dom N. Ated',
      'age' => 30,
      'married' => false,
      'pattern' => 'domn@ed',
      'email' => 'domn@ed.com',
      'gender' => 'male',
      'location' => { 'latitude' => 38.9013369,
                      'longitude' => -77.0316181 },
      'favoriteFood' => 'pizza',
      'hungry?' => false,
      'requiredField' => 'exists',
      'date' => '1969-12-31' }
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

    it 'respects object datatype' do
      data['location'] = Faker::Lorem.word
      expect(subject[:title]).to eq 'Invalid data type'
      expect(subject[:detail]).to eq 'Expected object data'
    end

    it 'respects array datatype' do
      data['favoriteFruits'] = Faker::Lorem.word
      expect(subject[:title]).to eq 'Invalid data type'
      expect(subject[:detail]).to eq 'Expected array data'
    end
  end

  context 'arrays' do
    it 'has title, detail, and meta' do
      data['favoriteFruits'] = %w[a b]
      expect(subject[:title]).to eq 'Invalid array'
      expect(subject[:detail]).to eq 'The 2 items provided did not match the definition'
      expected_keys = %i[received_size received_unique_items min_items max_items unique_items]
      expect(subject[:meta].keys).to match_array expected_keys
    end

    it 'shows received size & uniqueness in meta' do
      data['favoriteFruits'] = %w[a a a b c d e f]
      expect(subject[:meta][:received_size]).to eq 8
      expect(subject[:meta][:received_unique_items]).to be false
    end

    it 'respects maximum size' do
      data['favoriteFruits'] = %w[a b c d e f g h]
      expect(subject[:meta][:max_items]).to eq 5
    end

    it 'respects minimum size' do
      data['favoriteFruits'] = %w[a b]
      expect(subject[:meta][:min_items]).to eq 3
    end

    it 'respects uniqueness constraint' do
      data['favoriteFruits'] = %w[a a a a]
      expect(subject[:meta][:unique_items]).to be true
    end
  end

  context 'enums' do
    it 'has title, detail, and meta' do
      data['gender'] = Faker::Lorem.sentence
      expect(subject[:title]).to eq 'Invalid option'
      expect(subject[:detail]).to eq "'#{data['gender']}' is not an available option"
      expect(subject[:meta][:available_options]).to match_array %w[male female undisclosed]
    end
  end

  context 'const' do
    it 'has title, detail, and meta' do
      data['favoriteFood'] = Faker::Lorem.sentence
      expect(subject[:title]).to eq 'Invalid value'
      expect(subject[:detail]).to eq "'#{data['favoriteFood']}' does not match the provided const"
      expect(subject[:meta][:required_value]).to eq('pizza')
    end
  end

  context 'patterns' do
    it 'has title, detail, and meta' do
      data['pattern'] = Faker::Lorem.sentence
      expect(subject[:title]).to eq 'Invalid pattern'
      expect(subject[:detail]).to eq "'#{data['pattern']}' did not match the defined pattern"
      expect(subject[:meta][:regex]).to eq '.@.'
    end
  end

  context 'email' do
    it 'has title, detail, and meta' do
      data['email'] = Faker::Lorem.sentence
      expect(subject[:title]).to eq 'Invalid format'
      expect(subject[:detail]).to eq "'#{data['email']}' did not match the defined format"
      expect(subject[:meta][:format]).to eq 'email'
    end
  end

  context 'restraints' do
    it 'respects maximum length' do
      data['name'] = Faker::Lorem.sentence(word_count: 20)
      expect(subject[:title]).to eq 'Invalid length'
      expect(subject[:detail]).to eq "'#{data['name']}' did not fit within the defined length limits"
      expect(subject[:meta]).to eq({ max_length: 20, min_length: 3 })
    end

    it 'respects minimum length' do
      data['name'] = 'Ed'
      expect(subject[:title]).to eq 'Invalid length'
      expect(subject[:detail]).to eq "'#{data['name']}' did not fit within the defined length limits"
      expect(subject[:meta]).to eq({ max_length: 20, min_length: 3 })
    end

    it 'respects maximum value' do
      data['age'] = 150
      expect(subject[:title]).to eq 'Value outside range'
      expect(subject[:detail]).to eq "'#{data['age']}' is outside the defined range"
      expect(subject[:meta]).to eq({ maximum: 130, minimum: 21 })
    end

    it 'respects minimum value' do
      data['age'] = 18
      expect(subject[:title]).to eq 'Value outside range'
      expect(subject[:detail]).to eq "'#{data['age']}' is outside the defined range"
      expect(subject[:meta]).to eq({ maximum: 130, minimum: 21 })
    end
  end

  context 'extra data' do
    before { data['not_in_schema'] = Faker::Lorem.sentence }

    it 'points to problem source' do
      expect(pointer).to eq '/not_in_schema'
    end

    it 'has title and detail' do
      expect(subject[:title]).to eq 'Schema mismatch'
      expect(subject[:detail]).to eq 'Unknown data provided'
    end
  end

  context 'multiple errors on one field' do
    subject { described_class.new(@validator.validate(data).to_a).errors }

    it 'displays all errors found for that pointer' do
      data['pattern'] = 'A'
      expect(subject.size).to eq 2
      expect(subject.map { |e| e[:source][:pointer] }).to eq %w[/pattern /pattern]
      expect(subject.pluck(:code)).to match_array %w[142 143]
    end
  end

  context 'unknown error type' do
    it 'responds with generic validation error data with pointer' do
      schema = get_fixture 'json/detailed_schema_errors_schema'
      schema['definitions']['married']['type'] = 'null'
      validator = JSONSchemer.schema(schema)
      error = described_class.new(validator.validate(data).to_a).errors.first
      expect(error[:title]).to eq 'Validation error'
      expect(error[:code]).to eq '100'
      expect(error[:source][:pointer]).to eq '/married'
    end
  end

  context 'respects conditional fields' do
    it do
      data['hungry?'] = true
      expect(subject[:title]).to eq 'Missing required fields'
      expect(subject[:detail]).to eq 'One or more expected fields were not found'
      expect(subject[:meta][:missing_fields]).to eq ['dessert']
    end
  end

  context 'date' do
    it 'has title, detail, and meta' do
      data['date'] = '02/01/1979'
      expect(subject[:title]).to eq 'Invalid format'
      expect(subject[:detail]).to eq "'#{data['date']}' did not match the defined format"
      expect(subject[:meta][:format]).to eq 'date'
    end
  end
end
