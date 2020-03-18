# frozen_string_literal: true

require 'rails_helper'

describe Vet360::ContactInformation::TransactionResponse do
  describe '.from' do
    context 'with a response error' do
      before do
        described_class.from()
      end

      it 'should log that error to sentry' do
      end
    end
  end
end
