# frozen_string_literal: true
require 'rails_helper'

RSpec.describe Preneeds::FormFill do
  context 'with valid attributes' do
    subject { described_class.new(params) }

    let(:params) { attributes_for :form_fill }

    it 'populates attributes' do
      name_map = described_class.attribute_set.map(&:name)

      expect(name_map).to contain_exactly(
        :attachment_types, :branches_of_services, :cemeteries, :states, :discharge_types
      )

      expect(subject.attachment_types.first.to_h).to eq(params[:attachment_types].first)
      expect(subject.branches_of_services.first.to_h).to eq(params[:branches_of_services].first)
      expect(subject.cemeteries.first.to_h).to eq(params[:cemeteries].first)
      expect(subject.states.first.to_h).to eq(params[:states].first)
      expect(subject.discharge_types.first.to_h).to eq(params[:discharge_types].first)
    end
  end
end
