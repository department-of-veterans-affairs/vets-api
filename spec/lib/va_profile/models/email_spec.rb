# frozen_string_literal: true

require 'rails_helper'
require 'va_profile/models/email'

RSpec.describe VAProfile::Models::Email do
  subject(:email) { build(:email, email_address:) }

  let(:email_address) { 'valid_email@email.com' }

  describe 'validations' do
    context 'with a normal email' do
      it 'matches the regex and is valid' do
        expect(email.email_address).to match(VAProfile::Models::Email::VALID_EMAIL_REGEX)
        expect(email).to be_valid
      end
    end

    context 'when email is nil' do
      let(:email_address) { nil }

      it 'is not valid' do
        expect(email).not_to be_valid
        expect(email.errors[:email_address]).to be_present
      end
    end

    context 'when email is not an email' do
      let(:email_address) { 'not-an-email' }

      it 'is not valid' do
        expect(email).not_to be_valid
        expect(email.errors[:email_address]).to be_present
      end
    end

    context 'when email is missing a dot after @' do
      let(:email_address) { 'user@example' }

      it 'is not valid' do
        expect(email).not_to be_valid
      end
    end

    context 'when email is shorter than 6 characters' do
      let(:email_address) { 'a@b.c' }

      it 'is not valid' do
        expect(email).not_to be_valid
      end
    end

    context 'when email is longer than 255 characters' do
      let(:email_address) { "#{'a' * 250}@example.com" }

      it 'is not valid' do
        expect(email).not_to be_valid
      end
    end
  end

  describe '#in_json' do
    subject(:email) do
      build(:email, email_address:,
                    id:,
                    source_system_user:,
                    source_date:,
                    effective_start_date:,
                    effective_end_date:,
                    confirmation_date:,
                    verification_date:)
    end

    let(:id) { 42 }
    let(:source_system_user)   { 'some-system-user' }
    let(:source_date)          { Time.utc(2024, 3, 4, 5, 6, 7).iso8601(3) }
    let(:effective_start_date) { Time.utc(2024, 2, 3, 4, 5, 6).iso8601(3) }
    let(:effective_end_date)   { nil }
    let(:confirmation_date)    { Time.utc(2024, 1, 2, 3, 4, 5).iso8601(3) }
    let(:source_system)        { VAProfile::Models::Email::SOURCE_SYSTEM }
    # Recent date to ensure verification_date = true
    let(:verification_date)    do
      Time.utc(2025, 3, 4, 5, 6, 7).iso8601(3)
    end
    let(:expected_json) do
      {
        bio: {
          emailAddressText: email_address,
          emailId: id,
          originatingSourceSystem: source_system,
          sourceSystemUser: source_system_user,
          sourceDate: source_date,
          effectiveStartDate: effective_start_date,
          effectiveEndDate: effective_end_date,
          confirmationDate: confirmation_date,
          verificationDate: verification_date
        }
      }.to_json
    end

    it 'serializes to the VAProfile request shape' do
      expect(email.in_json).to eq(expected_json)
    end
  end

  describe 'confirmation_date correction' do
    subject(:email) do
      build(:email, email_address: 'test@example.com',
                    confirmation_date:,
                    source_date:)
    end

    let(:source_date_string) { '2024-01-01T12:00:00Z' }
    let(:source_date) { source_date_string }

    context 'when confirmation_date is after source_date' do
      let(:confirmation_date_string) { '2024-01-01T13:00:00Z' }
      let(:confirmation_date) { confirmation_date_string }

      it 'corrects confirmation_date to match source_date' do
        expect(email.valid?).to be(true)
        expect(email.confirmation_date).to eq(Time.iso8601(source_date_string))
      end
    end

    context 'when confirmation_date is before source_date' do
      let(:confirmation_date_string) { '2024-01-01T11:00:00Z' }
      let(:confirmation_date) { confirmation_date_string }

      it 'leaves confirmation_date unchanged' do
        expect(email.valid?).to be(true)
        expect(email.confirmation_date).to eq(Time.iso8601(confirmation_date_string))
      end
    end

    context 'when confirmation_date equals source_date' do
      let(:confirmation_date) { source_date_string }

      it 'leaves confirmation_date unchanged' do
        expect(email.valid?).to be(true)
        expect(email.confirmation_date).to eq(Time.iso8601(source_date_string))
      end
    end

    context 'when confirmation_date is nil' do
      let(:confirmation_date) { nil }

      it 'leaves confirmation_date as nil' do
        expect(email.valid?).to be(true)
        expect(email.confirmation_date).to be_nil
      end
    end

    context 'when source_date is nil' do
      let(:source_date) { nil }
      let(:confirmation_date) { source_date_string }

      it 'leaves confirmation_date unchanged' do
        expect(email.valid?).to be(true)
        expect(email.confirmation_date).to eq(Time.iso8601(source_date_string))
      end
    end

    context 'when both confirmation_date and source_date are nil' do
      let(:confirmation_date) { nil }
      let(:source_date) { nil }

      it 'leaves both as nil' do
        expect(email.valid?).to be(true)
        expect(email.confirmation_date).to be_nil
        expect(email.source_date).to be_nil
      end
    end

    context 'when source_date is set after confirmation_date (timing issue)' do
      let(:later_confirmation_date_string) { '2024-01-01T14:00:00Z' }

      it 'corrects confirmation_date when source_date is set later' do
        email = build(:email, email_address: 'test@example.com')
        # Simulate controller flow: confirmation_date string is set first during initialization
        email.confirmation_date = later_confirmation_date_string
        # Then source_date string is set by set_defaults (Time.zone.now.iso8601 returns a string)
        email.source_date = source_date_string

        expect(email.confirmation_date).to eq(Time.iso8601(source_date_string))
      end
    end

    context 'when confirmation_date is not a valid ISO8601 string' do
      it 'raises a TypeError' do
        email = build(:email, email_address: 'test@example.com')

        expect do
          email.confirmation_date = 'invalid-date'
        end.to raise_error(TypeError, 'confirmation_date is not iso8601')
      end
    end

    context 'when source_date is not a valid ISO8601 string' do
      it 'raises a TypeError' do
        email = build(:email, email_address: 'test@example.com')

        expect do
          email.source_date = 'invalid-date'
        end.to raise_error(TypeError, 'source_date is not iso8601')
      end
    end
  end

  describe '.build_from' do
    subject(:email) { described_class.build_from(body) }

    let(:create_date)          { Time.utc(2024, 1, 2, 3, 4, 5).iso8601(3) }
    let(:confirmation_date)    { Time.utc(2024, 2, 3, 4, 5, 6).iso8601(3) }
    let(:email_address_text)   { 'test@example.com' }
    let(:effective_end_date)   { nil }
    let(:effective_start_date) { Time.utc(2024, 3, 4, 5, 6, 7).iso8601(3) }
    let(:email_id)             { 88 }
    let(:source_date)          { Time.utc(2024, 4, 5, 6, 7, 8).iso8601(3) }
    let(:tx_audit_id)          { 'some-audit-id' }
    let(:update_date)          { Time.utc(2024, 5, 6, 7, 8, 9).iso8601(3) }
    # Recent date to ensure verification_date = true
    let(:verification_date)    do
      Time.utc(2025, 2, 3, 4, 5, 6).iso8601(3)
    end
    let(:vet360_id)            { 'some-vet360-id' }
    let(:va_profile_id)        { 'some-va-profile-id' }

    let(:body) do
      {
        create_date:,
        confirmation_date:,
        email_address_text:,
        effective_end_date:,
        effective_start_date:,
        email_id:,
        source_date:,
        tx_audit_id:,
        update_date:,
        verification_date:,
        vet360_id:,
        va_profile_id:
      }.as_json
    end

    it 'maps response body keys to model attributes' do
      expect(email.created_at).to eq(create_date)
      expect(email.confirmation_date).to eq(confirmation_date)
      expect(email.email_address).to eq(email_address_text)
      expect(email.effective_end_date).to be_nil
      expect(email.effective_start_date).to eq(effective_start_date)
      expect(email.id).to eq(email_id)
      expect(email.source_date).to eq(source_date)
      expect(email.transaction_id).to eq(tx_audit_id)
      expect(email.updated_at).to eq(update_date)
      expect(email.verification_date)
        .to be_within(1.second).of(Time.zone.parse(verification_date))
      expect(email.vet360_id).to eq(vet360_id)
      expect(email.va_profile_id).to eq(va_profile_id)
    end

    context 'when va_profile_id is missing' do
      let(:va_profile_id) { nil }

      it 'uses vet360_id for both vet360_id and va_profile_id' do
        expect(email.vet360_id).to eq(vet360_id)
        expect(email.va_profile_id).to eq(vet360_id)
      end
    end

    context 'when only vet360_id is missing' do
      let(:vet360_id) { nil }

      it 'uses va_profile_id for both vet360_id and va_profile_id' do
        expect(email.vet360_id).to eq(va_profile_id)
        expect(email.va_profile_id).to eq(va_profile_id)
      end
    end
  end

  describe '#contact_email_verified?' do
    let(:email) { build(:email) }

    context 'when verification_date is within the last year' do
      before { email.verification_date = 6.months.ago }

      it 'returns true' do
        expect(email.contact_email_verified?).to be true
      end
    end

    context 'when verification_date is exactly one year ago' do
      before { email.verification_date = 1.year.ago }

      it 'returns false' do
        expect(email.contact_email_verified?).to be false
      end
    end

    context 'when verification_date is more than one year ago' do
      before { email.verification_date = 2.years.ago }

      it 'returns false' do
        expect(email.contact_email_verified?).to be false
      end
    end

    context 'when verification_date is nil' do
      before { email.verification_date = nil }

      it 'returns false' do
        expect(email.contact_email_verified?).to be false
      end
    end

    context 'when verification_date is very recent' do
      before { email.verification_date = 1.day.ago }

      it 'returns true' do
        expect(email.contact_email_verified?).to be true
      end
    end

    context 'when verification_date is just under one year ago' do
      before { email.verification_date = 11.months.ago }

      it 'returns true' do
        expect(email.contact_email_verified?).to be true
      end
    end
  end
end
