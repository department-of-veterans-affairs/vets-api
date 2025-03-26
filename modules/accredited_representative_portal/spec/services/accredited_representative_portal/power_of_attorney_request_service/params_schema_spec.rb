# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AccreditedRepresentativePortal::PowerOfAttorneyRequestService::ParamsSchema do
  describe '.validate_and_normalize!' do
    subject { described_class.validate_and_normalize!(params) }

    context 'with empty params' do
      let(:params) { {} }

      it 'returns params with default values' do
        expect(subject).to eq(
          page: {
            number: 1,
            size: described_class::Page::Size::DEFAULT
          }
        )
      end
    end

    context 'with valid pagination params' do
      let(:params) { { page: { number: 2, size: 20 } } }

      it 'returns the validated params with specified values' do
        expect(subject).to eq(
          page: {
            number: 2,
            size: 20
          }
        )
      end
    end

    context 'with partial pagination params' do
      let(:params) { { page: { number: 3 } } }

      it 'applies defaults for missing params' do
        expect(subject).to eq(
          page: {
            number: 3,
            size: described_class::Page::Size::DEFAULT
          }
        )
      end
    end

    context 'with invalid page number' do
      let(:params) { { page: { number: 0 } } }

      it 'raises an error' do
        expect { subject }.to raise_error(ActionController::BadRequest, /Invalid parameters/)
      end
    end

    context 'with invalid page size' do
      context 'when below minimum' do
        let(:params) { { page: { size: described_class::Page::Size::MIN - 1 } } }

        it 'raises an error' do
          expect { subject }.to raise_error(ActionController::BadRequest, /Invalid parameters/)
        end
      end

      context 'when above maximum' do
        let(:params) { { page: { size: described_class::Page::Size::MAX + 1 } } }

        it 'raises an error' do
          expect { subject }.to raise_error(ActionController::BadRequest, /Invalid parameters/)
        end
      end
    end

    context 'with non-numeric values' do
      let(:params) { { page: { number: 'one', size: 'twenty' } } }

      it 'raises an error' do
        expect { subject }.to raise_error(ActionController::BadRequest, /Invalid parameters/)
      end
    end

    # These tests are placeholders for future PRs when filter/sort functionality is added
    context 'with future filter params (placeholder)' do
      let(:params) { { page: { number: 1 } } }

      it 'only validates current schema elements (pagination)' do
        expect(subject).to eq(
          page: {
            number: 1,
            size: described_class::Page::Size::DEFAULT
          }
        )
      end
    end
  end

  # Test the Schema constant directly for more granular validations
  describe 'Schema' do
    subject { described_class::Schema.call(params) }

    context 'with valid page params' do
      let(:params) { { page: { number: 2, size: 50 } } }

      it 'validates successfully' do
        expect(subject).to be_success
        expect(subject.to_h).to eq params
      end
    end

    context 'with string values that can be coerced' do
      let(:params) { { page: { number: '2', size: '50' } } }
      let(:expected) { { page: { number: 2, size: 50 } } }

      it 'coerces string values to integers' do
        expect(subject).to be_success
        expect(subject.to_h).to eq expected
      end
    end

    context 'with invalid page number format' do
      let(:params) { { page: { number: 'invalid' } } }

      it 'fails validation' do
        expect(subject).not_to be_success
        expect(subject.errors[:page][:number]).to include(match(/must be an integer/))
      end
    end

    context 'with invalid page size format' do
      let(:params) { { page: { size: 'invalid' } } }

      it 'fails validation' do
        expect(subject).not_to be_success
        expect(subject.errors[:page][:size]).to include(match(/must be an integer/))
      end
    end

    context 'with invalid page number value' do
      let(:params) { { page: { number: 0 } } }

      it 'fails validation with specific error' do
        expect(subject).not_to be_success
        expect(subject.errors[:page][:number]).to include(match(/must be greater than or equal to 1/))
      end
    end

    context 'with invalid page size value' do
      context 'when too small' do
        let(:params) { { page: { size: described_class::Page::Size::MIN - 1 } } }

        it 'fails validation with specific error' do
          expect(subject).not_to be_success
          expect(subject.errors[:page][:size]).to include(
            match(/must be greater than or equal to #{described_class::Page::Size::MIN}/)
          )
        end
      end

      context 'when too large' do
        let(:params) { { page: { size: described_class::Page::Size::MAX + 1 } } }

        it 'fails validation with specific error' do
          expect(subject).not_to be_success
          expect(subject.errors[:page][:size]).to include(
            match(/must be less than or equal to #{described_class::Page::Size::MAX}/)
          )
        end
      end
    end
  end
end
