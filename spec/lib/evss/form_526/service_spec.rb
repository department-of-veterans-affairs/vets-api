# frozen_string_literal: true

require 'rails_helper'

describe EVSS::Form526::Service do
  describe '#get_rated_disabilities' do
    let(:user) { build(:user, :loa3) }
    subject { described_class.new(user) }

    context 'with a valid evss response' do
      it 'returns an array of rated disabilities'
    end

    #this is intentionally vague until I know more
    context 'with an error' do
      it 'handles the error'
    end
  end

  describe '#submit_form' do
  end
end
