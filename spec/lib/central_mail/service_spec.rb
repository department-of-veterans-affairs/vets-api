# frozen_string_literal: true

require 'rails_helper'
require 'central_mail/service'
require 'securerandom'

RSpec.describe CentralMail::Service do

  let(:service) { described_class.new }

  describe '#status' do
    context 'with one uuid' do
      it 'retrieves the status' do
        VCR.use_cassette(
            'central_mail/status_one_uuid',
            match_requests_on: %i[body method uri]
        ) do
          response = described_class.new.status('34656d73-7c31-456d-9c49-2024fff1cd47')
          expect(response.status).to eq(200)
          expect(JSON.parse(response.body).length).to eq(1)
        end
      end
    end

    context 'with multiple uuids' do
      it 'retrieves the statuses' do
        VCR.use_cassette(
            'central_mail/status_multiple_uuids',
            match_requests_on: %i[body method uri]
        ) do
          response = described_class.new.status(
              %w[
              34656d73-7c31-456d-9c49-2024fff1cd47
              4a25588c-9200-4405-a2fd-97f0b0fdf790
              f7725cce-a76e-4d80-ab20-01c63acfcb87
            ]
          )
          expect(response.status).to eq(200)
          expect(JSON.parse(response.body).length).to eq(3)
        end
      end
    end
  end

  describe '#upload' do
    context 'with an bad response status' do
      it 'increments statsd' do
        expect(service).to receive(:request).and_return(
            OpenStruct.new(
                success?: false
            )
        )

        expect { service.upload('metadata' => nil) }.to trigger_statsd_increment(
                                                            'api.central_mail.upload.fail'
                                                        )
      end
    end

    let :valid_metadata do
      get_fixture('vba_documents/metadata')
    end

    let :vendor do
      'GDIT'
    end

    let :multipart_request_matcher do
      lambda do |r1, r2|
        [r1, r2].each { |r| normalized_multipart_request(r) }
        expect(r1.headers).to eq(r2.headers)
      end
    end

    let :upload_file do
      ->(metadata, document_path, attachment_path) do
        response = described_class.new.upload(
            metadata: metadata.to_json,
            document: Faraday::UploadIO.new(
                document_path,
                Mime[:pdf].to_s
            ),
            attachment1: Faraday::UploadIO.new(
                attachment_path,
                Mime[:pdf].to_s
            )
        )
        response
      end
    end

    let :upload_file_only do
      ->(metadata, document_path) do
        response = described_class.new.upload(
            metadata: metadata.to_json,
            document: Faraday::UploadIO.new(
                document_path,
                Mime[:pdf].to_s
            )
        )
        response
      end
    end

    valid_doc = 'spec/fixtures/vba_documents/form.pdf'
    valid_attach = 'spec/fixtures/vba_documents/attachment.pdf'
    locked_pdf = 'spec/fixtures/vba_documents/locked.pdf'

    let :response_helper do
      ->(metadata, key, missing_key = true) do
        response = upload_file.call(metadata, valid_doc, valid_attach)
        uuid = metadata['uuid']
        missing = missing_key ? 'Missing' : 'Invalid'
        expect(response.body.strip).to eq("Metadata Field Error - #{missing} #{key} [uuid: #{uuid}]")
        expect(response.status).to eq(412)
      end
    end

    context 'with missing metadata' do
      %w{veteranFirstName veteranLastName fileNumber zipCode}.each do |key|
        xit "Returns a 412 error when no #{key} is present" do
          VCR.use_cassette(
              "central_mail/bad_metadata_no_#{key}_#{vendor}",
              match_requests_on: [multipart_request_matcher, :method, :uri]
          ) do

            metadata = valid_metadata.except(key)
            response_helper.call(metadata, key)
          end
        end
      end
    end

    context 'with invalid metadata' do
      %w{veteranFirstName veteranLastName fileNumber zipCode}.each do |key|
        xit "Returns a 412 error when #{key} is blank" do
          VCR.use_cassette(
              "central_mail/bad_metadata_blank_#{key}_#{vendor}",
              match_requests_on: [multipart_request_matcher, :method, :uri]
          ) do

            metadata = valid_metadata.deep_dup
            metadata[key] = ''
            response_helper.call(metadata, key)
          end
        end
        if ['zipCode'].include?(key)
          xit "Returns a 412 error when #{key} is invalid" do
            VCR.use_cassette(
                "central_mail/bad_metadata_invalid_#{key}_#{vendor}",
                match_requests_on: [multipart_request_matcher, :method, :uri]
            ) do

              metadata = valid_metadata.deep_dup
              uuid = SecureRandom.uuid
              metadata['uuid'] = uuid
              metadata[key] = 'invalid_data'
              response_helper.call(metadata, key, false)
            end
          end
        end
      end
    end

    context 'with a valid file and metadata' do
      xit "upload succeeds with unique uuid" do
        VCR.use_cassette(
            "central_mail/upload_#{vendor}",
            match_requests_on: [multipart_request_matcher, :method, :uri]
        ) do

          metadata = valid_metadata.deep_dup
          uuid = SecureRandom.uuid
          metadata['uuid'] = uuid
          response = upload_file.call(metadata, valid_doc, valid_attach)
          expect(response.body.strip).to eq("Request was received successfully  [uuid: #{uuid}]")
          expect(response.status).to eq(200)
        end
      end

      xit "upload fails when uuid was uploaded previously" do
        VCR.use_cassette(
            "central_mail/upload_duplicate_#{vendor}",
            match_requests_on: [multipart_request_matcher, :method, :uri]
        ) do

          response = upload_file.call(valid_metadata, valid_doc, valid_attach)
          expect(response.body.strip).to eq("Document already uploaded with uuid  [uuid: #{valid_metadata['uuid']}]")
          expect(response.status).to eq(400)
        end
      end
    end

    context 'with a locked pdf' do
      it "upload fails with status 422" do
        VCR.use_cassette(
            "central_mail/upload_locked_#{vendor}",
            match_requests_on: [multipart_request_matcher, :method, :uri]
        ) do

          metadata = valid_metadata.deep_dup
          uuid = SecureRandom.uuid
          metadata['uuid'] = uuid
          response = upload_file.call(metadata, locked_pdf, valid_attach)
          expect(response.body.strip).to eq("password-protected pdf  [uuid: #{uuid}]")
          expect(response.status).to eq(422)
        end
      end
    end
  end
end
