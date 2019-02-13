# frozen_string_literal: true

require 'rails_helper'

describe HCA::EE::Service do
  describe '#lookup_user' do
    context 'with a user that has an ineligibility_reason' do
      it 'should get the ineligibility_reason' do
        VCR.use_cassette(
          'hca/ee/lookup_user_ineligibility_reason',
          record: :always
        ) do
          described_class.new.lookup_user('0000001013030524V532318000000')
        end
      end
    end

    it 'should lookup the user in the hca ee user', run_at: 'Fri, 08 Feb 2019 02:50:45 GMT' do
      VCR.use_cassette(
        'hca/ee/lookup_user',
        VCR::MATCH_EVERYTHING.merge(erb: true)
      ) do
        described_class.new.lookup_user('1013032368V065534')
      end
    end
  end
end
