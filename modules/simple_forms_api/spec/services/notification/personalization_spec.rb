# frozen_string_literal: true

require 'rails_helper'
require SimpleFormsApi::Engine.root.join('spec', 'spec_helper.rb')

describe SimpleFormsApi::Notification::Personalization do
  describe '#to_hash' do
    let(:date_submitted) { Time.zone.now }
    let(:config) { { date_submitted: } }
    let(:personalization) { described_class.new(form:, config:) }

    context 'form is a 21-0966' do
      let(:form) do
        SimpleFormsApi::VBA210966.new({ 'benefit_selection' => { 'compensation' => true },
                                        'veteran_full_name' => { 'first' => 'john' } })
      end
      let(:expiration_date) { 1.day.from_now }

      it 'returns a hash with ITF fields' do
        personalization = described_class.new(form:, config:, expiration_date:)

        expect(personalization.to_hash).to eq(
          {
            'first_name' => 'John',
            'date_submitted' => date_submitted,
            'intent_to_file_benefits' => 'disability compensation',
            'intent_to_file_benefits_links' => '[File for disability compensation (VA Form 21-526EZ)](https://www.va.gov/disability/file-disability-claim-form-21-526ez/introduction)',
            'itf_api_expiration_date' => expiration_date
          }
        )
      end
    end

    context 'should send to point of contact' do
      let(:form) do
        SimpleFormsApi::VBA2010207.new(
          {
            'veteran_full_name' => { 'first' => 'John', 'last' => 'Doe' },
            'preparer_type' => 'veteran',
            'living_situation' => { 'NONE' => true },
            'point_of_contact_name' => 'Pointy McContact'
          }
        )
      end

      it 'returns a hash with point of contact fields' do
        personalization = described_class.new(form:, config:)

        expect(personalization.to_hash).to eq(
          {
            'first_name' => 'John',
            'last_name' => 'Doe',
            'date_submitted' => date_submitted,
            'poc_first_name_last_name' => 'Pointy McContact'
          }
        )
      end
    end

    context 'other forms' do
      let(:form) { SimpleFormsApi::VBA2010206.new({ 'full_name' => { 'first' => 'john' } }) }

      context 'base case' do
        it 'returns a hash with first_name and date_submitted' do
          expect(personalization.to_hash).to eq({ 'first_name' => 'John', 'date_submitted' => date_submitted })
        end
      end

      context 'lighthouse_updated_at is provided' do
        let(:lighthouse_updated_at) { Time.zone.now }

        it 'returns a hash with first_name, date_submitted, and lighthouse_updated_at' do
          config[:lighthouse_updated_at] = lighthouse_updated_at

          expect(personalization.to_hash).to eq(
            {
              'first_name' => 'John',
              'date_submitted' => date_submitted,
              'lighthouse_updated_at' => lighthouse_updated_at
            }
          )
        end
      end

      context 'confirmation_number is provided' do
        let(:confirmation_number) { '123456' }

        it 'returns a hash with first_name, date_submitted, and confirmation_number' do
          config[:confirmation_number] = confirmation_number

          expect(personalization.to_hash).to eq(
            {
              'first_name' => 'John',
              'date_submitted' => date_submitted,
              'confirmation_number' => confirmation_number
            }
          )
        end
      end
    end
  end
end
