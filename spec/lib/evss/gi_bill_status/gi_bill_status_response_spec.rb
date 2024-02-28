# frozen_string_literal: true

require 'rails_helper'

describe EVSS::GiBillStatus::GiBillStatusResponse do
  describe '#inspect' do
    it 'does not include @response=' do
      instance = EVSS::GiBillStatus::GiBillStatusResponse.new('200')
      inspect_output = instance.inspect

      expect(inspect_output).not_to include('@response=')
    end
  end
end
