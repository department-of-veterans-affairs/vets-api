# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AccreditedRepresentativePortal::PowerOfAttorneyRequest, type: :model do
  describe 'associations' do
    it 'validates its form and claimant type' do
      poa_request = build(
        :power_of_attorney_request,
        power_of_attorney_form: build(
          :power_of_attorney_form,
          data: {}.to_json
        ),
        power_of_attorney_holder_type: 'abc'
      )

      expect(poa_request).not_to be_valid
    end
  end

  describe 'scopes' do
    let(:time) { Time.zone.parse('2024-12-21T04:45:37.000Z') }

    let(:poa_code) { 'x23' }

    describe '.sorted_by' do
      context 'using created_at column' do
        let!(:pending1) { create(:power_of_attorney_request, created_at: time, poa_code:) }
        let!(:pending2) { create(:power_of_attorney_request, created_at: time + 1.day, poa_code:) }
        let!(:pending3) { create(:power_of_attorney_request, created_at: time + 2.days, poa_code:) }

        it 'sorts by creation date ascending' do
          result = described_class.sorted_by('created_at', :asc)

          expect(result.first).to eq(pending1)
          expect(result.last).to eq(pending3)
        end

        it 'sorts by creation date descending' do
          result = described_class.sorted_by('created_at', :desc)

          expect(result.first).to eq(pending3)
          expect(result.last).to eq(pending1)
        end
      end

      context 'using resolution date' do
        let!(:accepted_request) do
          create(:power_of_attorney_request, :with_acceptance,
                 resolution_created_at: time,
                 created_at: time,
                 poa_code:)
        end

        let!(:declined_request) do
          create(:power_of_attorney_request, :with_declination,
                 resolution_created_at: time + 1.day,
                 created_at: time + 1.day,
                 poa_code:)
        end

        let!(:expired_request) do
          create(:power_of_attorney_request, :with_expiration,
                 resolution_created_at: time + 2.days,
                 created_at: time + 2.days,
                 poa_code:)
        end

        it 'sorts by resolution date ascending' do
          result = described_class.where.not(resolution: nil).sorted_by('resolved_at', :asc)

          expect(result).to eq([accepted_request, declined_request, expired_request])
        end

        it 'sorts by resolution date descending' do
          result = described_class.where.not(resolution: nil).sorted_by('resolved_at', :desc)

          expect(result).to eq([expired_request, declined_request, accepted_request])
        end
      end

      context 'with invalid column' do
        it 'raises argument error' do
          expect { described_class.sorted_by('invalid_column') }.to raise_error(ArgumentError)
        end
      end
    end
  end

  describe 'redaction' do
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

    describe '.unredacted scope' do
      it 'includes records that are not redacted and have a form' do
        expect(described_class.unredacted).to include(unredacted_record)
      end

      it 'excludes records that are fully redacted (timestamp set, form missing)' do
        expect(described_class.unredacted).not_to include(fully_redacted_record)
      end
    end

    describe '.redacted scope (strict definition)' do
      # Assuming .redacted requires timestamp AND missing form
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
end
