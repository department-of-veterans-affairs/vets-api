# frozen_string_literal: true

require 'rails_helper'

describe HCA::EE::Service do
  describe '#lookup_user' do
    it 'should lookup the user in the hca ee user' do
      VCR.use_cassette('hca/ee/lookup_user', record: :always) do
        described_class.new.lookup_user('1013032368V065534')
      end
    end
  end
end
