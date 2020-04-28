# frozen_string_literal: true

require 'rails_helper'

describe VAOS::V1::ErrorSerializer do
  describe 'json serialization' do
    context 'with a backend service exception' do
      let(:exception) { Common::Exceptions::BackendServiceException.new('VAOS_502') }

      it 'serializes the error in FHIR DSTU 2 format' do
        expect(VAOS::V1::ErrorSerializer.new(exception).new).to eq('a')
      end
    end
  end
end
