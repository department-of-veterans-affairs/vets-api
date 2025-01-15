# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Preneeds::DateRange do
  subject { described_class.new(params) }

  let(:params) { attributes_for(:date_range) }

  it 'specifies the permitted_params' do
    expect(described_class.permitted_params).to include(:from, :to)
  end

  describe 'when converting to json' do
    it 'converts its attributes from snakecase to camelcase' do
      camelcased = params.deep_transform_keys { |key| key.to_s.camelize(:lower) }
      expect(camelcased).to eq(subject.as_json)
    end
  end
end
