# frozen_string_literal: true

require 'rails_helper'
require SimpleFormsApi::Engine.root.join('spec', 'spec_helper.rb')
require 'simple_forms_api/form_remediation/configuration/vff_config'

module SimpleFormsApi
  module FormRemediation
    module Jobs
      RSpec.describe ArchiveBatchProcessingJob, type: :job do
        include FileUtilities

        let(:form_type) { '21-10210' }
        let(:form_data) do
          File.read("modules/simple_forms_api/spec/fixtures/form_json/vba_#{form_type.tr('-', '_')}.json")
        end
        let(:submissions) do
          create_list(:form_submission, 4, :pending, form_type:, form_data:) do |submission|
            submission.latest_attempt.update!(benefits_intake_uuid: SecureRandom.uuid)
          end
        end
        let(:benefits_intake_uuids) { submissions.map(&:latest_attempt).map(&:benefits_intake_uuid) }
        let(:config) { Configuration::VffConfig.new }
        let(:s3_client_double) { instance_double(S3Client) }

        describe '#perform' do
          subject(:perform) { described_class.new.perform(ids: benefits_intake_uuids, config:) }

          before do
            allow(S3Client).to receive(:new).and_return(s3_client_double)
            allow(s3_client_double).to receive(:upload).and_return('/s3/presigned/url')
            allow(File).to receive_messages(exist?: false, write: true)
            allow(Rails.logger).to receive(:info).and_call_original
          end

          context 'with valid parameters' do
            it 'processes all submissions and generates presigned URLs' do
              perform
              expect(Rails.logger).to have_received(:info).exactly(5).times
              expect(File).to have_received(:write).exactly(4).times
            end
          end

          context 'when ids are missing' do
            let(:benefits_intake_uuids) { [] }

            it 'raises a ParameterMissing error' do
              expect { perform }.to raise_error(Common::Exceptions::ParameterMissing, 'Missing parameter')
            end
          end

          context 'when an error occurs during archiving' do
            before { allow(s3_client_double).to receive(:upload).and_raise(StandardError.new('oopsy')) }

            it 'handles the error with the config handle_error method' do
              expect { perform }.to raise_error(SimpleFormsApi::FormRemediation::Error, a_string_including('oopsy'))
            end
          end
        end
      end
    end
  end
end
