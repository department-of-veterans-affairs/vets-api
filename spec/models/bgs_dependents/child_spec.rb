# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BGSDependents::Child do
  describe '#format_info' do
    let(:child_info) do
      {
        'child_status' => 'biological'
      }
    end
    it 'formats relationship params for submission' do
      formatted_info = described_class.new(child_info).format_info

      expect(formatted_info).to eq('foo')
    end
  end
end