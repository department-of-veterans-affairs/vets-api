# frozen_string_literal: true

require 'rails_helper'

describe ClaimsApi::PowerOfAttorneyRequestService::DataGatherer::Concerns::GathererUtilities do
  # Create a dummy class to include the concern for testing
  subject { dummy_class.new }

  let(:dummy_class) do
    Class.new do
      include ClaimsApi::PowerOfAttorneyRequestService::DataGatherer::Concerns::GathererUtilities
    end
  end

  describe '#parse_phone_number' do
    context 'with a valid 10-digit domestic number' do
      it 'parses area code and phone number without country code' do
        result = subject.parse_phone_number('5551234567')

        expect(result).to eq([nil, '555', '1234567'])
      end
    end

    context 'with a valid 11-digit number including country code' do
      it 'parses country code, area code, and phone number' do
        result = subject.parse_phone_number('15551234567')

        expect(result).to eq(%w[1 555 1234567])
      end
    end
  end
end
