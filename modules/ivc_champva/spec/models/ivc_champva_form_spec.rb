# frozen_string_literal: true

require 'rails_helper'

RSpec.describe IvcChampvaForm, type: :model do
  describe 'validations' do
    it 'requires form_uuid to be present' do
      form = described_class.new
      expect(form).not_to be_valid
      expect(form.errors[:form_uuid]).to include("can't be blank")
    end

    it 'is valid with required attributes' do
      form = described_class.new(form_uuid: SecureRandom.uuid)
      expect(form).to be_valid
    end
  end

  describe 'database operations' do
    let(:form_uuid) { SecureRandom.uuid }
    let(:test_email) { 'test@example.com' }
    let(:test_first_name) { 'John' }
    let(:test_last_name) { 'Doe' }

    describe 'creating and reading records' do
      it 'creates a record with encrypted personal data' do
        form = described_class.create!(
          form_uuid:,
          first_name: test_first_name,
          last_name: test_last_name,
          email: test_email,
          form_number: '10-10EZ',
          file_name: 'test_file.pdf'
        )

        expect(form).to be_persisted
        expect(form.id).to be_present
        expect(form.created_at).to be_present
        expect(form.updated_at).to be_present
      end

      it 'reads encrypted personal data correctly after creation' do
        form = described_class.create!(
          form_uuid:,
          first_name: test_first_name,
          last_name: test_last_name,
          email: test_email
        )

        # Reload from database to ensure we're testing actual persistence
        reloaded_form = described_class.find(form.id)

        expect(reloaded_form.first_name).to eq(test_first_name)
        expect(reloaded_form.last_name).to eq(test_last_name)
        expect(reloaded_form.email).to eq(test_email)
        expect(reloaded_form.form_uuid).to eq(form_uuid)
      end

      it 'stores encrypted data in ciphertext columns' do
        form = described_class.create!(
          form_uuid:,
          first_name: test_first_name,
          last_name: test_last_name,
          email: test_email
        )

        # Verify that the actual database columns contain encrypted data
        raw_record = described_class.connection.execute(
          'SELECT first_name_ciphertext, last_name_ciphertext, email_ciphertext ' \
          "FROM ivc_champva_forms WHERE id = #{form.id}"
        ).first

        expect(raw_record['first_name_ciphertext']).to be_present
        expect(raw_record['first_name_ciphertext']).not_to eq(test_first_name)

        expect(raw_record['last_name_ciphertext']).to be_present
        expect(raw_record['last_name_ciphertext']).not_to eq(test_last_name)

        expect(raw_record['email_ciphertext']).to be_present
        expect(raw_record['email_ciphertext']).not_to eq(test_email)
      end
    end

    describe 'querying by email' do
      let!(:form1) do
        described_class.create!(
          form_uuid: SecureRandom.uuid,
          first_name: 'Alice',
          last_name: 'Smith',
          email: 'alice@example.com'
        )
      end

      let!(:form2) do
        described_class.create!(
          form_uuid: SecureRandom.uuid,
          first_name: 'Bob',
          last_name: 'Johnson',
          email: 'bob@example.com'
        )
      end

      let!(:form3) do
        described_class.create!(
          form_uuid: SecureRandom.uuid,
          first_name: 'Charlie',
          last_name: 'Brown',
          email: 'alice@example.com' # Same email as form1
        )
      end

      it 'finds records by email using blind index' do
        results = described_class.where(email: 'alice@example.com')

        expect(results.count).to eq(2)
        expect(results.map(&:first_name)).to contain_exactly('Alice', 'Charlie')
      end

      it 'returns empty result for non-existent email' do
        results = described_class.where(email: 'nonexistent@example.com')

        expect(results).to be_empty
      end
    end

    describe 'updating encrypted fields' do
      let!(:form) do
        described_class.create!(
          form_uuid:,
          first_name: test_first_name,
          last_name: test_last_name,
          email: test_email
        )
      end

      it 'updates encrypted personal data correctly' do
        new_first_name = 'Jane'
        new_email = 'jane@example.com'

        form.update!(
          first_name: new_first_name,
          email: new_email
        )

        reloaded_form = described_class.find(form.id)
        expect(reloaded_form.first_name).to eq(new_first_name)
        expect(reloaded_form.last_name).to eq(test_last_name) # unchanged
        expect(reloaded_form.email).to eq(new_email)
      end
    end
  end
end
