# frozen_string_literal: true

require 'rails_helper'

RSpec.describe OracleRPAService do
  describe '#post_to_xrm' do
    context 'given a call' do
      it 'returns zero' do
        service = OracleRPAService.new(nil)
        expect(service.submit_form).to eq(0)
      end
    end
  end
end
