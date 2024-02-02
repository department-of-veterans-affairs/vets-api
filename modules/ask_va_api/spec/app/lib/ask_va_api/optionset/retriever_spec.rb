# frozen_string_literal: true

require 'rails_helper'

module AskVAApi
  module Optionset
    RSpec.describe Retriever do
      let(:entity_class) { Entity }
      let(:name) { 'branch_of_service' }
      let(:retriever) { described_class.new(name: 'branch_of_service', user_mock_data: true, entity_class:) }

      describe '#call' do
        it 'reads from file' do
          expect(retriever.call).to all(be_a(entity_class))
        end
      end
    end
  end
end
