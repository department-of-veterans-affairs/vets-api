# frozen_string_literal: true

class FakeVBMS
  attr_accessor :client

  delegate :send_request, to: :client

  def initialize(css_id: nil, station_id: nil, use_forward_proxy: false)
    self.client = VBMS::Client.new(
      base_url: 'http://test.endpoint.url/',
      keypass: 'importkey',
      client_keyfile: File.new(File.join(File.expand_path('../fixtures', __dir__), 'test_client.p12')),
      server_cert: File.new(File.join(File.expand_path('../fixtures', __dir__), 'test_server.crt')),
      saml: File.new(File.join(File.expand_path('../fixtures', __dir__), 'test_samltoken.xml')),
      css_id:,
      station_id:,
      use_forward_proxy:,
      proxy_base_url: use_forward_proxy ? 'http://localhost:3000' : nil
    )
  end
end
