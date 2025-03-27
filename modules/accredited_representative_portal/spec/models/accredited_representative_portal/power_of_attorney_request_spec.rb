# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AccreditedRepresentativePortal::PowerOfAttorneyRequest, type: :model do
  describe 'associations' do
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
  end

  describe 'scopes' do
    let(:time) { Time.zone.parse('2024-12-21T04:45:37.000Z') }

    let(:poa_code) { 'x23' }

    let(:pending1) { create(:power_of_attorney_request, created_at: time, poa_code:) }
    let(:pending2) { create(:power_of_attorney_request, created_at: time + 1.day, poa_code:) }
    let(:pending3) { create(:power_of_attorney_request, created_at: time + 2.days, poa_code:) }

    let(:accepted_request) do
      create(:power_of_attorney_request, :with_acceptance,
             resolution_created_at: time,
             created_at: time,
             poa_code:)
    end

    let(:declined_request) do
      create(:power_of_attorney_request, :with_declination,
             resolution_created_at: time + 1.day,
             created_at: time + 1.day,
             poa_code:)
    end

    let(:expired_request) do
      create(:power_of_attorney_request, :with_expiration,
             resolution_created_at: time + 2.days,
             created_at: time + 2.days,
             poa_code:)
    end

    describe '.sorted_by' do
      context 'using created_at column' do
        before do
          pending1
          pending2
          pending3
        end

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
        before do
          accepted_request
          declined_request
          expired_request
        end

        it 'sorts by resolution date ascending' do
          result = described_class.where.not(resolution: nil).sorted_by('resolved_at', :asc)

          expect(result.first).to eq(accepted_request)
          expect(result.second).to eq(declined_request)
          expect(result.third).to eq(expired_request)
        end

        it 'sorts by resolution date descending' do
          result = described_class.where.not(resolution: nil).sorted_by('resolved_at', :desc)

          expect(result.first).to eq(expired_request)
          expect(result.second).to eq(declined_request)
          expect(result.third).to eq(accepted_request)
        end
      end

      context 'with invalid column' do
        it 'raises argument error' do
          expect { described_class.sorted_by('invalid_column') }.to raise_error(ArgumentError)
        end
      end
    end
  end
end
