# frozen_string_literal: true

require 'rails_helper'

module AskVAApi
  module Inquiries
    module Status
      RSpec.describe Entity do
        subject(:entity) { described_class.new(info) }

        let(:info) { { Status: 'Reopened' } }

        it 'creates a status' do
          expect(entity).to be_a(Entity)
        end
      end
    end
  end
end
