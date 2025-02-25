# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Preneeds::FullName do
  subject { described_class.new(params) }

  let(:params) { attributes_for(:full_name) }

  it 'specifies the permitted_params' do
    expect(described_class.permitted_params).to include(:first, :last, :maiden, :middle, :suffix)
  end

  describe 'when converting to eoas' do
    it 'produces an ordered hash' do
      expect(subject.as_eoas.keys).to eq(%i[firstName lastName maidenName middleName suffix])
    end

    it 'removes maidenName, middleName, and suffix if blank' do
      params[:maiden] = ''
      params[:middle] = ''
      params[:suffix] = ''
      expect(subject.as_eoas.keys).not_to include(:maidenName, :middleName, :suffix)
    end
  end

  describe 'when converting to json' do
    it 'converts its attributes from snakecase to camelcase' do
      camelcased = params.deep_transform_keys { |key| key.to_s.camelize(:lower) }
      expect(camelcased).to eq(subject.as_json)
    end
  end
end
