# frozen_string_literal: true
require 'rails_helper'

RSpec.describe Preneeds::MilitaryStatus do
  subject { described_class.new(params) }

  let(:params) { attributes_for :military_status }

  it 'specifies the permitted_params' do
    expect(described_class.permitted_params).to include(
      :veteran, :retired_active_duty, :died_on_active_duty, :retired_reserve, :death_inactive_duty, :other
    )
  end

  describe 'when converting to eoas' do
    it 'produces an array of string values' do
      expect(subject.as_eoas).to eq('V')
    end

    it 'only includes true attributes' do
      params[:veteran] = nil
      params[:retired_active_duty] = false
      expect(subject.as_eoas).not_to include('V', 'E')
    end
  end

  describe 'when converting to json' do
    it 'converts its attributes from snakecase to camelcase' do
      camelcased = params.deep_transform_keys { |key| key.to_s.camelize(:lower) }
      expect(camelcased).to eq(subject.as_json)
    end
  end
end
