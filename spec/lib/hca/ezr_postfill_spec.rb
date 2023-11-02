# frozen_string_literal: true

require 'rails_helper'
require 'hca/ezr_postfill'

describe HCA::EzrPostfill do
  let(:user) { create(:user, :loa3) }

  before do
    allow(user).to receive(:icn).and_return('1013032368V065534')
  end

  describe '#post_fill_hash', run_at: 'Fri, 08 Feb 2019 02:50:45 GMT' do
    it 'returns the post fill hash' do
      VCR.use_cassette(
        'hca/ee/lookup_user',
        VCR::MATCH_EVERYTHING.merge(erb: true)
      ) do
        expect(described_class.post_fill_hash(user)).to eq(
          {
            'isEssentialAcaCoverage' => false,
            'vaMedicalFacility' => '988'
          }
        )
      end
    end
  end
end
