# frozen_string_literal: true

require 'rails_helper'
require 'support/disability_compensation/service_configuration_helper'

require Rails.root.join('rakelib', 'disability_compensation', 'download_claim_documents')

module DisabilityCompensation
  module DownloadClaimDocuments
    module SpecHelpers
      FAKE_RSA_KEY_PATH = 'spec/support/certificates/lhdd-fake-private.pem'

      def with_lighthouse_token_signing_key(cassette_recording, &)
        return yield if cassette_recording

        settings = Settings.lighthouse
        rsa_key = FAKE_RSA_KEY_PATH

        with_settings(settings.benefits_claims.access_token, { rsa_key: }) do
          with_settings(settings.auth.ccg, { rsa_key: }, &)
        end
      end

      class MockFileIO
        def calls = @calls ||= []

        OPERATIONS = %i[write binwrite mkdir_p].freeze
        OPERATIONS.each do |operation|
          define_method(operation) do |subject, *|
            subject = subject.to_s
            calls << { operation:, subject: }
          end
        end
      end
    end
  end
end

describe DisabilityCompensation::DownloadClaimDocuments do
  include described_class::SpecHelpers
  include DisabilityCompensation::ServiceConfigurationHelper

  before do
    reset_service_configuration(
      BenefitsClaims::Service,
      BenefitsClaims::Configuration
    )

    reset_service_configuration(
      BenefitsDocuments::Service,
      BenefitsDocuments::Configuration
    )
  end

  it 'writes files with network-derived data' do
    mock_file_io = described_class::SpecHelpers::MockFileIO.new
    allow(described_class).to(receive(:file_io).and_return(mock_file_io))

    vcr_name = 'disability_compensation/download_claim_documents'
    vcr_options = {
      match_requests_on: %i[method uri],
      allow_unused_http_interactions: false
    }.freeze

    VCR.use_cassette(vcr_name, vcr_options) do |cassette|
      with_lighthouse_token_signing_key(cassette.recording?) do
        described_class.perform(
          claim_id: '600878948',
          icn: '1012667122V019349'
        )
      end
    end

    directory = 'tmp/disability_compensation/download_claim_documents/600878948'

    expect(mock_file_io.calls).to match(
      [
        {
          subject: a_string_ending_with(directory),
          operation: :mkdir_p
        },
        {
          subject: a_string_ending_with("#{directory}/claim.json"),
          operation: :write
        },
        {
          subject: a_string_ending_with("#{directory}/va-21-526-veterans-application-for-compensation-or-pension1.pdf"),
          operation: :binwrite
        },
        {
          subject: a_string_ending_with("#{directory}/birth-certificate1.pdf"),
          operation: :binwrite
        },
        {
          subject: a_string_ending_with("#{directory}/court-documents-general1.pdf"),
          operation: :binwrite
        },
        {
          subject: a_string_ending_with("#{directory}/court-documents-general2.pdf"),
          operation: :binwrite
        }
      ]
    )
  end
end
