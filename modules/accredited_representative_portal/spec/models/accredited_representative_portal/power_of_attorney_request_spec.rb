# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AccreditedRepresentativePortal::PowerOfAttorneyRequest, type: :model do
  # Optional: Record missing form but not timestamped (might be invalid state anyway)
  let!(:formless_unredacted_record) do
    build(:power_of_attorney_request) # Build only
    # Explicitly don't associate a form - this might fail validation on save depending on factory
    # For testing scopes that don't save, this might work, otherwise needs different setup
    # A better way might be to save then destroy form without setting redacted_at
    request_saved = create(:power_of_attorney_request)
    request_saved.power_of_attorney_form&.destroy!
    request_saved.reload
  end
  let!(:fully_redacted_record) do
    request = create(:power_of_attorney_request)
    request.power_of_attorney_form&.destroy # Ensure form is gone
    request.update_column(:redacted_at, Time.current) # rubocop:disable Rails/SkipsModelValidations
    request.reload # Reload to get fresh state
  end

  # Has form, redacted_at is set
  let!(:incompletely_redacted_record) do
    create(:power_of_attorney_request, redacted_at: Time.current)
  end
  let!(:unredacted_record) { create(:power_of_attorney_request) } # Has form, redacted_at is nil

  it 'validates its form and claimant type' do
    poa_request =
      build(
        :power_of_attorney_request,
        power_of_attorney_form: build(
          :power_of_attorney_form,
          data: {}.to_json
        ),
        power_of_attorney_holder_type: 'abc'
      )

    expect(poa_request).not_to be_valid
    expect(poa_request.errors.full_messages).to contain_exactly(
      'Claimant type is not included in the list',
      'Power of attorney holder type is not included in the list',
      'Power of attorney form data does not comply with schema'
    )
  end

  # For the scopes, we're using just the timestamp for convenience
  describe '.unredacted scope' do
    it 'includes records that are not redacted and have a form' do
      expect(described_class.unredacted).to include(unredacted_record)
    end

    it 'excludes records that are fully redacted (timestamp set, form missing)' do
      expect(described_class.unredacted).not_to include(fully_redacted_record)
    end
  end

  # For the scopes, we're using just the timestamp for convenience
  describe '.redacted scope' do
    it 'includes records that are fully redacted (timestamp set, form missing)' do
      expect(described_class.redacted).to include(fully_redacted_record)
    end

    it 'excludes records that are unredacted (timestamp nil, form present)' do
      expect(described_class.redacted).not_to include(unredacted_record)
    end

    it 'excludes records that are not timestamped but missing a form' do
      expect(described_class.redacted).not_to include(formless_unredacted_record)
    end
  end
end
