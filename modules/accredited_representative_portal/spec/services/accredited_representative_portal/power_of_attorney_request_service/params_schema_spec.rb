# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AccreditedRepresentativePortal::PowerOfAttorneyRequestService::ParamsSchema do
  describe '.validate_and_normalize!' do
    subject { described_class.validate_and_normalize!(params) }

    context 'with sort by but no sort order' do
      let(:params) { { sort: { by: 'created_at' } } }

      it 'applies default sort order' do
        expect(subject).to eq(
          page: {
            number: 1,
            size: described_class::Page::Size::DEFAULT
          },
          sort: {
            by: 'created_at',
            order: described_class::Sort::DEFAULT_ORDER
          }
        )
      end
    end

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

    context 'with valid status parameter' do
      let(:params) { { status: 'pending' } }

      it 'returns the validated params with the status' do
        expect(subject).to eq(
          page: {
            number: 1,
            size: described_class::Page::Size::DEFAULT
          },
          status: 'pending'
        )
      end
    end

    context 'with invalid status parameter' do
      let(:params) { { status: 'invalid_status' } }

      it 'raises an error' do
        expect { subject }.to raise_error(ActionController::BadRequest, /Invalid parameters/)
      end
    end

    context 'with combination of params' do
      let(:params) { { page: { number: 2 }, status: 'processed', sort: { by: 'created_at' } } }

      it 'returns all validated parameters' do
        expect(subject).to eq(
          page: {
            number: 2,
            size: described_class::Page::Size::DEFAULT
          },
          status: 'processed',
          sort: {
            by: 'created_at',
            order: described_class::Sort::DEFAULT_ORDER
          }
        )
      end
    end
  end

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

    context 'with valid sort params' do
      let(:params) { { sort: { by: 'created_at', order: 'desc' } } }

      it 'validates successfully' do
        expect(subject).to be_success
        expect(subject.to_h).to eq params
      end
    end

    context 'with invalid sort by parameter' do
      let(:params) { { sort: { by: 'invalid_field' } } }

      it 'fails validation' do
        expect(subject).not_to be_success
        expect(subject.errors[:sort][:by]).to include(match(/must be one of/))
      end
    end

    context 'with invalid sort order parameter' do
      let(:params) { { sort: { by: 'created_at', order: 'invalid_order' } } }

      it 'fails validation' do
        expect(subject).not_to be_success
        expect(subject.errors[:sort][:order]).to include(match(/must be one of/))
      end
    end

    context 'with valid status parameter' do
      let(:params) { { status: 'pending' } }

      it 'validates successfully' do
        expect(subject).to be_success
        expect(subject.to_h).to eq params
      end
    end

    context 'with valid processed status' do
      let(:params) { { status: 'processed' } }

      it 'validates successfully' do
        expect(subject).to be_success
        expect(subject.to_h).to eq params
      end
    end

    context 'with invalid status parameter' do
      let(:params) { { status: 'not_a_valid_status' } }

      it 'fails validation' do
        expect(subject).not_to be_success
        expect(subject.errors[:status]).to include(match(/must be one of/))
      end
    end

    context 'with combined parameters' do
      let(:params) do
        {
          page: { number: 3, size: 25 },
          sort: { by: 'created_at', order: 'asc' },
          status: 'processed'
        }
      end

      it 'validates all parameters successfully' do
        expect(subject).to be_success
        expect(subject.to_h).to eq params
      end
    end
  end
end
