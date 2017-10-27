# frozen_string_literal: true
require 'rails_helper'

RSpec.describe Preneeds::AttachmentType do
  context 'with valid attributes' do
    subject { described_class.new(params) }

    let(:params) { attributes_for :preneeds_attachment_type }
    let(:other) { described_class.new(attributes_for(:preneeds_attachment_type)) }

    it 'populates attributes' do
      name_map = described_class.attribute_set.map(&:name)

      expect(name_map).to contain_exactly(:description, :attachment_type_id)
      expect(subject.attachment_type_id).to eq(params[:attachment_type_id])
      expect(subject.description).to eq(params[:description])
    end
  end
end
