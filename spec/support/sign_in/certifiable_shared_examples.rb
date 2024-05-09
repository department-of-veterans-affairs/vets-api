# frozen_string_literal: true

RSpec::Matchers.define :matching_public_key_for do |expected_public_key|
  match do |actual_public_key|
    actual_public_key.to_der == expected_public_key.to_der
  end
end

RSpec.shared_examples 'implements certifiable concern' do
  let(:certificate) do
    File.read('spec/fixtures/sign_in/sample_client.crt')
  end

  before do
    subject.certificates = [certificate]
    subject.save
  end

  describe '#assertion_public_keys' do
    it 'expands all certificates in the configuration to an array of public keys' do
      certificate_object = OpenSSL::X509::Certificate.new(certificate)
      expect(subject.assertion_public_keys).to include matching_public_key_for(certificate_object.public_key)
    end
  end
end
