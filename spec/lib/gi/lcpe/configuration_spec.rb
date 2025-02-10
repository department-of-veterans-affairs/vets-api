# frozen_string_literal: true

require 'rails_helper'
require 'gi/lcpe/configuration'

describe GI::LCPE::Configuration do
  describe '#request_headers' do
    let(:config) { GI::LCPE::Configuration.instance }

    context 'when etag nil' do
      it 'does not include If-None-Match header' do
        expect(config.etag).to be_nil
        expect(config.connection.headers).not_to include('If-None-Match')
      end
    end

    context 'when etag present' do
      before { config.etag = 3 }

      it 'includes If-None-Match header' do
        expect(config.connection.headers).to include('If-None-Match' => config.etag)
      end
    end
  end
end
