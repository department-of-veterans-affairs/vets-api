# frozen_string_literal: true
require 'rails_helper'

RSpec.describe MessageDraft do
  context 'with valid attributes' do
    subject { described_class.new(params) }

    let(:params) { attributes_for :message }

    it 'aliases draft_id for id' do
      expect(subject.draft_id).to eq(subject.id)
    end
  end
end
