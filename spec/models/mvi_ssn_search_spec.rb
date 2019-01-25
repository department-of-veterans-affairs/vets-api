require 'rails_helper'

RSpec.describe MviSsnSearch do
  describe('.truncate_ssn') do
    it 'should get the first 3 and last 4 of the ssn' do
      expect(described_class.truncate_ssn('111-55-1234')).to eq(
        '1111234'
      )
    end
  end
end
