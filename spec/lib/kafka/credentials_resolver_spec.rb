# frozen_string_literal: true

require "rails_helper"
require "aws-sdk-kafka"

RSpec.describe Kafka::CredentialsResolver, type: :model do
  describe "#from_credential_provider_chain" do
    context "when no credentials are available" do
      it "raises an error" do
        stub = Aws::Kafka::Client.new(stub_responses: true, credentials: nil)
        Aws::Kafka::Client.stub :new, stub do
          resolver = Kafka::CredentialsResolver.new
          expect { resolver.from_credential_provider_chain("us-east-1") }.to raise_error(RuntimeError)
        end
      end
    end

    context "when credentials are available" do
      it "returns an Aws::Credentials object" do
        stub = Aws::Kafka::Client.new(stub_responses: true)
        Aws::Kafka::Client.stub :new, stub do
          resolver = Kafka::CredentialsResolver.new
          credentials = resolver.from_credential_provider_chain("us-east-1")
          expect(credentials).to be_a(Aws::Credentials)
        end
      end
    end
  end

  describe "#from_profile" do
    it "returns an Aws::Credentials object" do
      creds = Aws::Credentials.new("access_key_id", "secret_access", "session_token")
      Aws::SharedCredentials.stub :new, creds do
        resolver = Kafka::CredentialsResolver.new
        credentials = resolver.from_profile("test-profile")
        expect(credentials).to be_a(Aws::Credentials)
      end
    end
  end

  describe "#from_role_arn" do
    it "returns a credentials provider" do
      stub = Aws::STS::Client.new(stub_responses: true)
      Aws::STS::Client.stub :new, stub do
        resolver = Kafka::CredentialsResolver.new
        credentials_provider = resolver.from_role_arn(
          role_arn: "arn:aws-msk-iam-sasl-signer:iam::123456789012:role/role-name",
          session_name: "test-session"
        )
        expect(credentials_provider).to respond_to(:credentials)
      end
    end
  end
end
