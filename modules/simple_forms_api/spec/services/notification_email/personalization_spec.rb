# frozen_string_literal: true

require 'rails_helper'
require SimpleFormsApi::Engine.root.join('spec', 'spec_helper.rb')

describe SimpleFormsApi::NotificationEmail::Personalization do
  context '20-10206' do
    let(:fixture_path) do
      Rails.root.join('modules', 'simple_forms_api', 'spec', 'fixtures', 'form_json',
                      'vba_20_10206.json')
    end
    let(:form_number) { 'vba_20_10206' }

    describe '#as_hash' do
      let(:form_data) { JSON.parse(fixture_path.read) }
      let(:confirmation_number) { 'confirmation-number' }
      let(:date_submitted) { Time.zone.today.strftime('%B %d, %Y') }
      let(:lighthouse_updated_at) { Time.current }
      let(:config) do
        {
          form_data:,
          form_number:,
          confirmation_number:,
          date_submitted:,
          lighthouse_updated_at:
        }
      end

      it 'returns the correct hash data' do
        expected_hash = {
          'first_name' => 'John',
          'date_submitted' => date_submitted,
          'confirmation_number' => confirmation_number,
          'lighthouse_updated_at' => lighthouse_updated_at
        }

        expect(described_class.new(config).as_hash).to eq expected_hash
      end
    end
  end

  context '20-10207' do
    let(:form_number) { 'vba_20_10207' }

    context 'submitter is veteran' do
      let(:fixture_path) do
        Rails.root.join('modules', 'simple_forms_api', 'spec', 'fixtures', 'form_json',
                        'vba_20_10207-veteran.json')
      end

      describe '#as_hash' do
        let(:form_data) { JSON.parse(fixture_path.read) }
        let(:confirmation_number) { 'confirmation-number' }
        let(:date_submitted) { Time.zone.today.strftime('%B %d, %Y') }
        let(:lighthouse_updated_at) { Time.current }
        let(:config) do
          {
            form_data:,
            form_number:,
            confirmation_number:,
            date_submitted:,
            lighthouse_updated_at:
          }
        end

        it 'returns the correct hash data' do
          expected_hash = {
            'first_name' => 'John',
            'date_submitted' => date_submitted,
            'confirmation_number' => confirmation_number,
            'lighthouse_updated_at' => lighthouse_updated_at
          }

          expect(described_class.new(config).as_hash).to eq expected_hash
        end
      end
    end

    context 'submitter is non-veteran' do
      let(:fixture_path) do
        Rails.root.join('modules', 'simple_forms_api', 'spec', 'fixtures', 'form_json',
                        'vba_20_10207-non-veteran.json')
      end

      describe '#as_hash' do
        let(:form_data) { JSON.parse(fixture_path.read) }
        let(:confirmation_number) { 'confirmation-number' }
        let(:date_submitted) { Time.zone.today.strftime('%B %d, %Y') }
        let(:lighthouse_updated_at) { Time.current }
        let(:config) do
          {
            form_data:,
            form_number:,
            confirmation_number:,
            date_submitted:,
            lighthouse_updated_at:
          }
        end

        it 'returns the correct hash data' do
          expected_hash = {
            'first_name' => 'John',
            'date_submitted' => date_submitted,
            'confirmation_number' => confirmation_number,
            'lighthouse_updated_at' => lighthouse_updated_at
          }

          expect(described_class.new(config).as_hash).to eq expected_hash
        end
      end
    end

    context 'submitter is third party' do
      let(:fixture_path) do
        Rails.root.join('modules', 'simple_forms_api', 'spec', 'fixtures', 'form_json',
                        'vba_20_10207-third-party-non-veteran.json')
      end

      describe '#as_hash' do
        let(:form_data) { JSON.parse(fixture_path.read) }
        let(:confirmation_number) { 'confirmation-number' }
        let(:date_submitted) { Time.zone.today.strftime('%B %d, %Y') }
        let(:lighthouse_updated_at) { Time.current }
        let(:config) do
          {
            form_data:,
            form_number:,
            confirmation_number:,
            date_submitted:,
            lighthouse_updated_at:
          }
        end

        it 'returns the correct hash data' do
          expected_hash = {
            'first_name' => 'Joe',
            'date_submitted' => date_submitted,
            'confirmation_number' => confirmation_number,
            'lighthouse_updated_at' => lighthouse_updated_at
          }

          expect(described_class.new(config).as_hash).to eq expected_hash
        end
      end
    end
  end

  context '21-0845' do
    let(:fixture_path) do
      Rails.root.join('modules', 'simple_forms_api', 'spec', 'fixtures', 'form_json',
                      'vba_21_0845.json')
    end
    let(:form_number) { 'vba_21_0845' }

    describe '#as_hash' do
      let(:form_data) { JSON.parse(fixture_path.read) }
      let(:confirmation_number) { 'confirmation-number' }
      let(:date_submitted) { Time.zone.today.strftime('%B %d, %Y') }
      let(:lighthouse_updated_at) { Time.current }
      let(:config) do
        {
          form_data:,
          form_number:,
          confirmation_number:,
          date_submitted:,
          lighthouse_updated_at:
        }
      end

      it 'returns the correct hash data' do
        expected_hash = {
          'first_name' => 'John',
          'date_submitted' => date_submitted,
          'confirmation_number' => confirmation_number,
          'lighthouse_updated_at' => lighthouse_updated_at
        }

        expect(described_class.new(config).as_hash).to eq expected_hash
      end
    end
  end

  context '21-0966' do
    let(:form_numbers) { %w[vba_21_0966 vba_21_0966_intent_api] }

    form_numbers.each do |form_number|
      context 'submitter is veteran' do
        let(:fixture_path) do
          Rails.root.join('modules', 'simple_forms_api', 'spec', 'fixtures', 'form_json',
                          'vba_21_0966-min.json')
        end

        describe '#as_hash' do
          let(:form_data) { JSON.parse(fixture_path.read) }
          let(:confirmation_number) { 'confirmation-number' }
          let(:date_submitted) { Time.zone.today.strftime('%B %d, %Y') }
          let(:lighthouse_updated_at) { Time.current }
          let(:config) do
            {
              form_data:,
              form_number:,
              confirmation_number:,
              date_submitted:,
              lighthouse_updated_at:
            }
          end

          it 'returns the correct hash data' do
            expected_hash = {
              'first_name' => 'Veteran',
              'date_submitted' => date_submitted,
              'confirmation_number' => confirmation_number,
              'lighthouse_updated_at' => lighthouse_updated_at
            }

            expect(described_class.new(config).as_hash).to eq expected_hash
          end
        end
      end

      context 'submitter is surviving dependent' do
        let(:fixture_path) do
          Rails.root.join('modules', 'simple_forms_api', 'spec', 'fixtures', 'form_json',
                          'vba_21_0966.json')
        end

        describe '#as_hash' do
          let(:form_data) { JSON.parse(fixture_path.read) }
          let(:confirmation_number) { 'confirmation-number' }
          let(:date_submitted) { Time.zone.today.strftime('%B %d, %Y') }
          let(:lighthouse_updated_at) { Time.current }
          let(:config) do
            {
              form_data:,
              form_number:,
              confirmation_number:,
              date_submitted:,
              lighthouse_updated_at:
            }
          end

          it 'returns the correct hash data' do
            expected_hash = {
              'first_name' => 'I',
              'date_submitted' => date_submitted,
              'confirmation_number' => confirmation_number,
              'lighthouse_updated_at' => lighthouse_updated_at
            }

            expect(described_class.new(config).as_hash).to eq expected_hash
          end
        end
      end
    end
  end
end
