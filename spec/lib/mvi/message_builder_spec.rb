require 'rails_helper'
require 'mvi/message_builder'

describe MVI::MessageBuilder do
  describe 'header' do
    it 'should generate a valid header' do
      builder = MVI::MessageBuilder.new
      expect(
        builder.build_find_candidate('123456789', 'John', 'Smith', Date.new(1980, 1, 1), '555-11-4477')
      ).to eq('xml') # TODO(AJD): validate against xsd
    end
  end
end
