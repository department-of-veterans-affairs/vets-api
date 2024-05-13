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

  describe '#expired_certificates' do
    let(:expired_certificate) do
      File.read('spec/fixtures/sign_in/sample_expired_client.crt')
    end

    context 'when certificates does not include an expired certificate' do
      it 'does not include the expired certificate' do
        expired_certificate_object = OpenSSL::X509::Certificate.new(expired_certificate)
        expect(subject.expired_certificates).not_to include(expired_certificate_object)
      end

      it 'does not include the non-expired certificate' do
        certificate_object = OpenSSL::X509::Certificate.new(certificate)
        expect(subject.expired_certificates).not_to include(certificate_object)
      end
    end

    context 'when certificates include an expired certificate' do
      before do
        subject.certificates = [certificate, expired_certificate]
      end

      it 'includes the expired certificate' do
        expired_certificate_object = OpenSSL::X509::Certificate.new(expired_certificate)
        expect(subject.expired_certificates).to include(expired_certificate_object)
      end

      it 'does not include the non-expired certificate' do
        certificate_object = OpenSSL::X509::Certificate.new(certificate)
        expect(subject.expired_certificates).not_to include(certificate_object)
      end
    end
  end
end
