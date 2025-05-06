# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Preneeds::Address do
  subject { described_class.new(params) }

  context 'with US/CAN address' do
    let(:params) { attributes_for(:address) }

    it 'specifies the permitted_params' do
      expect(described_class.permitted_params).to include(
        :street, :street2, :city, :country, :postal_code, :state
      )
    end

    describe 'when converting to eoas' do
      it 'produces an ordered hash' do
        expect(subject.as_eoas.keys).to eq(%i[address1 address2 city countryCode postalZip state])
      end

      it 'removes address2 if blank' do
        params[:street2] = ''
        expect(subject.as_eoas.keys).not_to include(:address2)
      end
    end

    describe 'when converting to json' do
      it 'converts its attributes from snakecase to camelcase' do
        camelcased = params.deep_transform_keys { |key| key.to_s.camelize(:lower) }
        expect(camelcased).to eq(subject.as_json)
      end
    end
  end

  context 'with foreign address' do
    let(:params) { attributes_for(:foreign_address) }

    it 'treats nil state as empty string' do
      expect(subject.as_eoas[:state]).to eq('')
    end
  end
end
