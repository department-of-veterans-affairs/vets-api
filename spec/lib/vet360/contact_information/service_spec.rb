# frozen_string_literal: true

require 'rails_helper'

describe Vet360::ContactInformation::Service do
  let(:user) { build(:user, :loa3) }
  subject { described_class.new(user) }

  before do
    allow(user).to receive(:vet360_id).and_return('123456')
  end

  describe '#get_person' do
    context 'when successful' do
      it 'returns a status of 200' do
        VCR.use_cassette('vet360/contact_information/person') do
          response = subject.get_person
byebug
          expect(response).to be_ok
        end
      end
    end
  end
end
