# frozen_string_literal: true

require "rails_helper"
require "aws-sdk-kafka"
require "aws-sdk-sts"
require "base64"

class TestCredentialsProvider
  include Aws::CredentialProvider

  def initialize
    @credentials = Aws::Credentials.new(
      "access_key_id",
      "secret_access_key",
      "session_token"
    )
  end

  attr_reader :credentials
end

RSpec.describe Kafka::MSKTokenProvider do
  let(:token_provider) { described_class.new(region: "us-east-1") }
  let(:creds) { Aws::Credentials.new("access_key_id", "secret_access", "session_token") }

  describe "#generate_auth_token" do
    it "generates a valid auth token" do
      allow_any_instance_of(Kafka::CredentialsResolver)
        .to receive(:from_credential_provider_chain)
        .and_return(creds)

      auth_token = token_provider.generate_auth_token
      assert_token(auth_token)
    end
  end

  describe "#generate_auth_token with AWS debug" do
    it "includes caller identity when aws_debug is true" do
      allow_any_instance_of(Kafka::CredentialsResolver)
        .to receive(:from_credential_provider_chain)
        .and_return(creds)

      allow(Aws::STS::Client).to receive(:new).and_return(Aws::STS::Client.new(stub_responses: true))

      auth_token = token_provider.generate_auth_token(aws_debug: true)

      expect(auth_token.caller_identity).not_to be_nil
      expect(auth_token.caller_identity).to be_a(Kafka::MSKTokenProvider::CallerIdentity)
    end
  end

  describe "#generate_auth_token_from_profile" do
    it "generates a valid auth token from profile" do
      allow_any_instance_of(Kafka::CredentialsResolver)
        .to receive(:from_profile)
        .and_return(creds)

      auth_token = token_provider.generate_auth_token_from_profile("test-profile")
      assert_token(auth_token)
    end
  end

  describe "#generate_auth_token_from_role_arn" do
    it "generates a valid auth token from role ARN" do
      allow_any_instance_of(Kafka::CredentialsResolver)
        .to receive(:from_role_arn)
        .and_return(creds)

      auth_token = token_provider.generate_auth_token_from_role_arn("role_arn")
      assert_token(auth_token)
    end
  end

  describe "#generate_auth_token_from_credentials_provider" do
    it "generates a valid auth token from a credentials provider" do
      auth_token = token_provider.generate_auth_token_from_credentials_provider(TestCredentialsProvider.new)
      assert_token(auth_token)
    end
  end

  def assert_token(auth_token)
    decoded_signed_url, params = parse_url(auth_token.token)

    assert_url(decoded_signed_url)
    assert_query_parameters(params)
    assert_credentials(params)
    assert_expiration_time_ms(params, auth_token.expiration_time_ms)
  end

  def parse_url(signed_url)
    decoded_signed_url = Base64.urlsafe_decode64(signed_url)
    uri = URI.parse(decoded_signed_url)
    params = URI.decode_www_form(uri.query).group_by(&:first).transform_values { |a| a.map(&:last) }
    [decoded_signed_url, params]
  end

  def assert_url(decoded_signed_url)
    expect(decoded_signed_url).to match("https://kafka.us-east-1.amazonaws.com/?Action=kafka-cluster%3AConnect")
  end

  def assert_query_parameters(params)
    expect(params["Action"].first).to eq("kafka-cluster:Connect")
    expect(params["X-Amz-Algorithm"].first).to eq("AWS4-HMAC-SHA256")
    expect(params["X-Amz-Security-Token"].first).to eq("session_token")
    expect(params["X-Amz-SignedHeaders"].first).to eq("host")
    expect(params["X-Amz-Expires"].first).to eq("900")
    expect(params["User-Agent"].first).to match("aws-msk-iam-sasl-signer-msk-iam-sasl-signer-ruby")
  end

  def assert_credentials(params)
    credentials = params["X-Amz-Credential"].first
    split_credentials = credentials.split("/")
    expect(split_credentials[0]).to eq("access_key_id")
    expect(split_credentials[2]).to eq("us-east-1")
    expect(split_credentials[3]).to eq("kafka-cluster")
    expect(split_credentials[4]).to eq("aws4_request")
  end

  def assert_expiration_time_ms(params, expiration_time_ms)
    date_obj = DateTime.strptime(params["X-Amz-Date"].first, "%Y%m%dT%H%M%SZ")
    current_time = Time.now.utc.to_i
    expect(date_obj.to_time.to_i).to be <= current_time

    actual_expires = 1000 * (params["X-Amz-Expires"].first.to_i + date_obj.to_time.to_i)
    expect(expiration_time_ms).to eq(actual_expires)
  end
end
