# frozen_string_literal: true

shared_examples 'shared model validations' do |opts|
  opts = opts.with_indifferent_access
  # Decision reviews expects some data in auth_headers, while segmented APIs expect all data in form_data
  let(:decision_reviews?) { appeal.api_version != 'V0' }

  # All claimant headers across appeal models
  all_claimant_headers = %w[
    X-VA-NonVeteranClaimant-First-Name
    X-VA-NonVeteranClaimant-Middle-Initial
    X-VA-NonVeteranClaimant-Last-Name
    X-VA-NonVeteranClaimant-Birth-Date
  ].freeze

  describe '#veteran_birth_date_is_in_the_past' do
    next unless opts[:validations].include? :veteran_birth_date_is_in_the_past

    before do
      if decision_reviews?
        appeal.auth_headers = appeal.auth_headers.merge 'X-VA-Birth-Date' => '3000-01-02'
      else
        appeal.form_data['data']['attributes']['veteran']['birthDate'] = '3000-01-02'
        appeal.send(:clear_memoized_values)
      end
    end

    context 'when birth date is in the future' do
      it 'errors with source at the veteran birth date header or data' do
        expect(appeal.valid?).to be false
        expect(appeal.errors.size).to eq 1
        error = appeal.errors.first
        if appeal.api_version == 'V0'
          expect(error.attribute.to_s).to eq('/data/attributes/veteran/birthDate')
        else
          expect(error.options[:source]).to eq({ header: 'X-VA-Birth-Date' })
        end
        expect(error.message).to eq 'Date must be in the past: 3000-01-02'
      end
    end
  end

  describe '#contestable_issue_dates_are_in_the_past' do
    next unless opts[:validations].include? :contestable_issue_dates_are_in_the_past

    before do
      data = appeal.form_data
      data['included'][0]['attributes']['decisionDate'] = '3000-01-02'
      appeal.form_data = data
      appeal.send(:clear_memoized_values)
    end

    context 'when issue date is in the future' do
      it 'errors with source to the issue where the date failed' do
        expect(appeal.valid?).to be false
        expect(appeal.errors.size).to eq 1
        error = appeal.errors.first
        expect(error.attribute.to_s).to eq '/data/included[0]/attributes/decisionDate'
        expect(error.message).to eq 'Date must be in the past: 3000-01-02'
      end
    end
  end

  describe '#claimant_birth_date_is_in_the_past' do
    next unless opts[:validations].include? :claimant_birth_date_is_in_the_past

    before do
      if decision_reviews?
        appeal.auth_headers = appeal.auth_headers.merge('X-VA-NonVeteranClaimant-Birth-Date' => '3000-01-02')
      else
        appeal.form_data['data']['attributes']['claimant']['birthDate'] = '3000-01-02'
        appeal.send(:clear_memoized_values)
      end
    end

    context 'when claimant birth date is in the future' do
      it 'errors with pointer to claimant birthdate header' do
        expect(appeal.valid?).to be false
        expect(appeal.errors.size).to eq 1
        error = appeal.errors.first
        if decision_reviews?
          expect(error.options[:source]).to eq({ header: 'X-VA-NonVeteranClaimant-Birth-Date' })
        else
          expect(error.attribute.to_s).to eq('/data/attributes/claimant/birthDate')
        end
        expect(error.message).to eq 'Date must be in the past: 3000-01-02'
      end
    end
  end

  describe '#required_claimant_data_is_present' do
    next unless opts[:validations].include? :required_claimant_data_is_present

    let!(:required_claimant_headers) do
      opts[:required_claimant_headers].presence || raise(StandardError, 'missing required_claimant_headers option key')
    end

    context 'when claimant form data is provided but headers are missing' do
      before { appeal.auth_headers = appeal.auth_headers.except(*all_claimant_headers) }

      it 'errors with detail to missing required non-veteran claimant headers' do
        expect(appeal.valid?).to be false
        expect(appeal.errors.size).to eq 1
        error = appeal.errors.first
        expect(error.options[:meta]).to match_array({ missing_fields: required_claimant_headers })
        expect(error.message).to include 'missing non-veteran claimant headers'
      end
    end

    context 'when non-veteran claimant headers are provided but missing form data' do
      before do
        appeal.auth_headers['X-VA-NonVeteranClaimant-First-Name'] = 'Betty'
        data = appeal.form_data
        data.dig('data', 'attributes').delete('claimant')
        appeal.form_data = data
      end

      it 'errors with details around the missing data' do
        expect(appeal.valid?).to be false
        expect(appeal.errors.size).to eq 1
        error = appeal.errors.first
        expect(error.message).to include 'Non-veteran claimant headers were provided but missing'
        expect(error.options[:meta]).to eq({ missing_fields: ['claimant'] })
      end
    end

    context 'when both claimant and form data are missing' do
      before do
        appeal.auth_headers = appeal.auth_headers.except(*all_claimant_headers)
        data = appeal.form_data
        data.dig('data', 'attributes').delete('claimant')
        appeal.form_data = data
      end

      it 'creates a valid record' do
        expect(appeal.valid?).to be true
      end
    end
  end

  describe '#country_codes_valid' do
    next unless opts[:validations].include? :country_codes_valid

    let(:field_name) { decision_reviews? ? 'countryCodeISO2' : 'countryCodeIso3' }
    let(:expected_length) { decision_reviews? ? 'two' : 'three' }
    let(:bad_code) { decision_reviews? ? 'ZZ' : 'ZZZ' }
    let(:expected_message) { "'#{bad_code}' is not a valid #{expected_length} letter country code" }

    context 'when veteran country code is invalid' do
      before do
        appeal.form_data['data']['attributes']['veteran']['address'][field_name] = bad_code
        appeal.send(:clear_memoized_values)
      end

      it 'errors with details around the invalid data' do
        expect(appeal.valid?).to be false
        expect(appeal.errors.size).to eq 1
        error = appeal.errors.first
        expect(error.message).to eq expected_message
        expect(error.attribute.to_s).to eq "/data/attributes/veteran/address/#{field_name}"
      end
    end

    context 'when claimant country code is invalid' do
      before do
        appeal.form_data['data']['attributes']['claimant']['address'][field_name] = bad_code
        appeal.send(:clear_memoized_values)
      end

      it 'errors with details around the invalid data' do
        expect(appeal.valid?).to be false
        expect(appeal.errors.size).to eq 1
        error = appeal.errors.first
        expect(error.message).to eq expected_message
        expect(error.attribute.to_s).to eq "/data/attributes/claimant/address/#{field_name}"
      end
    end
  end
end
