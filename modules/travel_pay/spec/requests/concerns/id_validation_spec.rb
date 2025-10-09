# frozen_string_literal: true

require 'rails_helper'

RSpec.describe IdValidation do
  # Dummy class so we can test the concern methods
  let(:dummy_class) do
    Class.new do
      include IdValidation
    end
  end

  let(:instance) { dummy_class.new }
  let(:id) { '3fa85f64-5717-4562-b3fc-2c963f66afa6' }

  describe '#validate_uuid_exists!' do
    context 'when id and id_type is not set' do
      it 'raises BadRequest with required message' do
        expect { instance.validate_uuid_exists!(nil) }.to raise_error do |error|
          expect(error).to be_a(Common::Exceptions::BadRequest)
          expect(error.errors.first[:detail]).to eq('An ID is required')
        end
      end
    end

    context 'when id is nil' do
      it 'raises BadRequest with required message' do
        expect { instance.validate_uuid_exists!(nil, 'Claim') }.to raise_error do |error|
          expect(error).to be_a(Common::Exceptions::BadRequest)
          expect(error.errors.first[:detail]).to eq('Claim ID is required')
        end
      end
    end

    context 'when id is blank' do
      it 'raises BadRequest with required message' do
        expect { instance.validate_uuid_exists!('', 'Claim') }.to raise_error do |error|
          expect(error).to be_a(Common::Exceptions::BadRequest)
          expect(error.errors.first[:detail]).to eq('Claim ID is required')
        end
      end
    end

    context 'when id is invalid format' do
      it 'raises BadRequest with invalid message' do
        expect { instance.validate_uuid_exists!('not-a-uuid', 'Document') }.to raise_error do |error|
          expect(error).to be_a(Common::Exceptions::BadRequest)
          expect(error.errors.first[:detail]).to eq('Document ID is invalid')
        end
      end
    end

    context 'when id is valid UUID' do
      it 'does not raise' do
        expect { instance.validate_uuid_exists!(id, 'Claim') }.not_to raise_error
      end
    end

    context 'when id is valid UUID and id_type is nil' do
      it 'does not raise' do
        expect { instance.validate_uuid_exists!(id) }.not_to raise_error
      end
    end
  end
end
