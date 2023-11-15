# frozen_string_literal: true

# Reference: https://github.com/goldeneggg/faraday_adapter_socks/blob/master/spec/faraday/adapter/net_http_socks_spec.rb

require 'rails_helper'

describe Faraday::Adapter::NetHttpSocks do
  describe 'setup' do
    it 'has 3 SOCKS_SCHEMES' do
      schemes = Faraday::Adapter::NetHttpSocks::SOCKS_SCHEMES
      expect(schemes.size).to eq(3)
      expect(schemes).to eq(%w[socks socks4 socks5].freeze)
    end
  end

  describe 'Faraday#new' do
    let(:faraday) do
      Faraday.new(url, options) do |faraday|
        faraday.adapter adapter
      end
    end
    let(:url) { 'http://example.com' }

    shared_examples_for 'adapter is instance of Faraday::Adapter::NetHttpSocks' do
      it 'has a Faraday::Adapter::NetHttpSocks instance' do
        expect(faraday).to respond_to('app')
        adapter = faraday.app
        expect(adapter).to be_instance_of(Faraday::Adapter::NetHttpSocks)

        uri = URI(url)
        http = adapter.net_http_connection({ url: uri, request: options })
        if options[:proxy].nil?
          expect(http).to be_instance_of(Net::HTTP)
        elsif Faraday::Adapter::NetHttpSocks::SOCKS_SCHEMES.include?(options[:proxy][:uri].scheme)
          expect(http.class).to respond_to(:socks_server)
        else
          expect(http.class).not_to respond_to(:socks_server)
        end
      end
    end

    shared_examples_for 'adapter is instance of Faraday::Adapter::NetHttp' do
      it 'has a Faraday::Adapter::NetHttp instance' do
        expect(faraday).to respond_to('app')

        adapter = faraday.app
        expect(adapter).to be_instance_of(Faraday::Adapter::NetHttp)

        uri = URI(url)
        http = adapter.net_http_connection({ url: uri, request: options })
        expect(http).to be_instance_of(Net::HTTP)
      end
    end

    context 'when adapter is :net_http_socks' do
      let(:adapter) { :net_http_socks }

      context 'when options has :proxy value' do
        let(:options) { { proxy: { uri: proxy_uri } } }
        let(:proxy_uri) { URI.parse(proxy_addr) }

        context 'when :uri option is included socks schemes' do
          let(:proxy_addr) { 'socks://example.com:8888' }

          it_behaves_like 'adapter is instance of Faraday::Adapter::NetHttpSocks'
        end

        context 'when :uri option is not included socks schemes' do
          let(:proxy_addr) { 'http://example.com:8889' }

          it_behaves_like 'adapter is instance of Faraday::Adapter::NetHttpSocks'
        end
      end

      context 'when options does not have :proxy value' do
        let(:options) { {} }

        it_behaves_like 'adapter is instance of Faraday::Adapter::NetHttpSocks'
      end
    end

    context 'when adapter is not :net_http_socks' do
      let(:adapter) { Faraday.default_adapter }
      let(:options) { {} }

      it_behaves_like 'adapter is instance of Faraday::Adapter::NetHttp'
    end
  end
end
