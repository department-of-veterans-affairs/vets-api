# frozen_string_literal: true

RSpec.shared_examples 'labs and tests response structure validation' do |response_data_path|
  let(:labs_data) do
    parsed = JSON.parse(response.body)
    response_data_path ? parsed.dig(*response_data_path) : parsed
  end

  it 'returns the expected number of lab records' do
    expect(labs_data.length).to eq(29)
  end

  it 'each record has required top-level structure' do
    expect(labs_data).to all(have_key('id').and(have_key('type')).and(have_key('attributes')))
  end

  it 'each record has type DiagnosticReport' do
    labs_data.each do |lab|
      expect(lab['type']).to eq('DiagnosticReport')
    end
  end

  it 'each record has required attributes' do
    labs_data.each do |lab|
      attributes = lab['attributes']
      expect(attributes).to include('status', 'dateCompleted', 'testCode')
    end
  end

  it 'each record has either encodedData or observations' do
    labs_data.each do |lab|
      attributes = lab['attributes']
      has_encoded_data = attributes['encodedData'].present?
      has_observations = attributes['observations'].present? && attributes['observations'].any?
      expect(has_encoded_data || has_observations).to be_truthy
    end
  end

  it 'observations have proper structure when present' do
    lab_with_observations = labs_data.find do |lab|
      lab['attributes']['observations'].present? && lab['attributes']['observations'].any?
    end

    skip 'No observations in test data' if lab_with_observations.nil?

    observation = lab_with_observations['attributes']['observations'].first
    expect(observation).to be_a(Hash)
    expect(observation).to include('testCode', 'status', 'value')
    expect(observation['value']).to be_a(Hash)
    expect(observation['value']).to have_key('text')
    expect(observation['value']).to have_key('type')
  end

  it 'observation values have valid types when present' do
    valid_value_types = %w[quantity codeable-concept string date-time]

    labs_with_observations = labs_data.select do |lab|
      lab['attributes']['observations'].present? && lab['attributes']['observations'].any?
    end

    skip 'No observations in test data' if labs_with_observations.empty?

    labs_with_observations.each do |lab|
      lab['attributes']['observations'].each do |obs|
        next unless obs['value'] && obs['value']['type']

        error_message = "Expected observation value type to be one of #{valid_value_types.join(', ')}, " \
                        "got #{obs['value']['type']}"
        expect(valid_value_types).to include(obs['value']['type']), error_message
      end
    end
  end

  it 'encodedData is present and non-empty when included' do
    lab_with_encoded = labs_data.find do |lab|
      lab['attributes']['encodedData'].present?
    end

    skip 'No encodedData in test data' if lab_with_encoded.nil?

    encoded = lab_with_encoded['attributes']['encodedData']
    expect(encoded).to be_a(String)
    expect(encoded).not_to be_empty
  end

  it 'dateCompleted is a valid ISO8601 timestamp' do
    labs_data.each do |lab|
      date_completed = lab['attributes']['dateCompleted']
      expect(date_completed).to match(/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}/)
    end
  end

  it 'status values are valid FHIR diagnostic report statuses' do
    valid_statuses = %w[registered preliminary final amended corrected cancelled entered-in-error unknown]
    labs_data.each do |lab|
      status = lab['attributes']['status']
      expect(valid_statuses).to include(status),
                                "Expected status to be one of #{valid_statuses.join(', ')}, got #{status}"
    end
  end

  it 'testCode is present and non-empty' do
    labs_data.each do |lab|
      test_code = lab['attributes']['testCode']
      expect(test_code).to be_present
      expect(test_code).to be_a(String)
    end
  end

  it 'display field is present when included' do
    labs_data.each do |lab|
      display = lab['attributes']['display']
      next if display.nil?

      expect(display).to be_a(String)
      expect(display).not_to be_empty
    end
  end

  it 'sampleTested field is a string when included' do
    labs_data.each do |lab|
      sample_tested = lab['attributes']['sampleTested']
      next if sample_tested.nil?

      expect(sample_tested).to be_a(String)
    end
  end

  it 'location field is a string when included' do
    labs_data.each do |lab|
      location = lab['attributes']['location']
      next if location.nil?

      expect(location).to be_a(String)
    end
  end

  it 'orderedBy field is a string when included' do
    labs_data.each do |lab|
      ordered_by = lab['attributes']['orderedBy']
      next if ordered_by.nil?

      expect(ordered_by).to be_a(String)
    end
  end

  it 'bodySite field is a string when included' do
    labs_data.each do |lab|
      body_site = lab['attributes']['bodySite']
      next if body_site.nil?

      expect(body_site).to be_a(String)
    end
  end

  it 'observations have all required subfields when present' do
    labs_with_observations = labs_data.select do |lab|
      lab['attributes']['observations'].present? && lab['attributes']['observations'].any?
    end

    skip 'No observations in test data' if labs_with_observations.empty?

    labs_with_observations.each do |lab|
      lab['attributes']['observations'].each do |obs|
        expect(obs).to have_key('testCode')
        expect(obs).to have_key('status')
        expect(obs).to have_key('value')

        # testCode must be present and a string
        expect(obs['testCode']).to be_present
        expect(obs['testCode']).to be_a(String)

        # status must be a valid FHIR status
        valid_statuses = %w[registered preliminary final amended corrected cancelled entered-in-error unknown]
        expect(valid_statuses).to include(obs['status']) if obs['status'].present?

        # value must have text and type
        value = obs['value']
        expect(value).to have_key('text')
        expect(value).to have_key('type')

        # Optional fields should be strings when present
        expect(obs['referenceRange']).to be_a(String) if obs['referenceRange'].present?
        expect(obs['comments']).to be_a(String) if obs['comments'].present?
        expect(obs['bodySite']).to be_a(String) if obs['bodySite'].present?
        expect(obs['sampleTested']).to be_a(String) if obs['sampleTested'].present?
      end
    end
  end

  it 'observation value text is non-empty when present' do
    labs_with_observations = labs_data.select do |lab|
      lab['attributes']['observations'].present? && lab['attributes']['observations'].any?
    end

    skip 'No observations in test data' if labs_with_observations.empty?

    labs_with_observations.each do |lab|
      lab['attributes']['observations'].each do |obs|
        value_text = obs.dig('value', 'text')
        next if value_text.nil?

        expect(value_text).not_to be_empty
      end
    end
  end
end

RSpec.shared_examples 'labs and tests specific data validation' do |response_data_path = nil|
  let(:labs_data) do
    parsed = JSON.parse(response.body)
    response_data_path ? parsed.dig(*response_data_path) : parsed
  end

  # Verify specific Vista lab record with encodedData
  it 'contains the Vista lab record with expected ID and encodedData' do
    vista_lab = labs_data.find { |lab| lab['id'] == 'f752ad57-a21d-4306-8910-7dd5dbc0a32e' }
    expect(vista_lab).not_to be_nil, 'Expected to find Vista lab with ID f752ad57-a21d-4306-8910-7dd5dbc0a32e'

    attributes = vista_lab['attributes']
    expect(attributes['testCode']).to eq('urn:va:lab-category:MI')
    expect(attributes['status']).to eq('final')
    expect(attributes['dateCompleted']).to eq('2025-02-27T11:51:00+00:00')
    expect(attributes['encodedData']).to be_present
    expect(attributes['encodedData'].length).to eq(956)

    # Decode and verify actual content
    decoded_data = Base64.decode64(attributes['encodedData'])
    expect(decoded_data).to include('Accession [UID]: MICRO 25 14 [1225000')
    expect(decoded_data).to include('Collection sample: BLOOD')
    expect(decoded_data).to include('Test(s) ordered: BLOOD CULTURE')
    expect(decoded_data).to include('Provider: MCGUIRE,MARCI P')

    expect(attributes['observations']).to be_nil.or be_empty
  end

  # Verify specific Oracle Health lab record with observations
  it 'contains the Oracle Health lab record with expected observations' do
    oracle_lab = labs_data.find { |lab| lab['id'] == 'b9552dee-1a50-4ce9-93cd-dcd1d02165b3' }
    expect(oracle_lab).not_to be_nil, 'Expected to find Oracle Health lab with ID b9552dee-1a50-4ce9-93cd-dcd1d02165b3'

    attributes = oracle_lab['attributes']
    expect(attributes['testCode']).to eq('CH')
    expect(attributes['status']).to eq('final')
    expect(attributes['encodedData']).to be_blank

    observations = attributes['observations']
    expect(observations).to be_an(Array)
    expect(observations).not_to be_empty

    first_obs = observations.first
    expect(first_obs['testCode']).to eq('URINE COLOR')
    expect(first_obs['status']).to eq('final')
    expect(first_obs.dig('value', 'type')).to eq('string')
    expect(first_obs.dig('value', 'text')).to eq('clear')
  end
end
