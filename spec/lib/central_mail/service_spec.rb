# frozen_string_literal: true

require 'rails_helper'
require 'central_mail/service'
require 'securerandom'

# Re-recording VCR Cassettes
# 1. Replace "<CENTRAL_MAIL_TOKEN>" with Settings.central_mail.upload.token from Staging
# 2. Delete exsiting cassette file
# 3. Re-run spec

RSpec.describe CentralMail::Service do
  let(:service) { described_class.new }

  describe '#status' do
    context 'with one uuid' do
      it 'retrieves the status' do
        VCR.use_cassette(
          'central_mail/status_one_uuid',
          match_requests_on: %i[method uri]
        ) do
          uuid = 'a8c29dbc-a0a6-4177-ae57-fc6143ec7edb'
          response = described_class.new.status(uuid)
          expect(response.status).to eq(200)
          expect(JSON.parse(response.body).length).to eq(1)
        end
      end
    end

    context 'with multiple uuids' do
      it 'retrieves the statuses' do
        VCR.use_cassette(
          'central_mail/status_multiple_uuids',
          match_requests_on: %i[method uri]
        ) do
          uuids = %w[
            a8c29dbc-a0a6-4177-ae57-fc6143ec7edb
            b2b677e3-a6c1-4d07-ae7d-e013d60bec43
            84bb3df3-c090-44a7-aa0d-76e9ab97eab0
          ]

          response = described_class.new.status(uuids)
          expect(response.status).to eq(200)
          expect(JSON.parse(response.body).length).to eq(3)
        end
      end
    end
  end

  describe '#upload' do
    before do
      @uuid = SecureRandom.uuid
    end

    valid_doc = 'spec/fixtures/vba_documents/form.pdf'
    valid_attach = 'spec/fixtures/vba_documents/attachment.pdf'
    locked_pdf = 'spec/fixtures/vba_documents/locked.pdf'

    let :multipart_request_matcher do
      lambda do |r1, r2|
        [r1, r2].each { |r| normalized_multipart_request(r) }
        expect(r1.headers).to eq(r2.headers)
      end
    end
    let :regex_match_expectation do
      lambda do |message|
        uuid_regex = '\[uuid:\s[\w]{8}-[\w]{4}-[\w]{4}-[\w]{4}-[\w]{12}\]'
        "#{message}\s+#{uuid_regex}"
      end
    end
    let :response_helper do
      lambda do |metadata, key, missing_key = true|
        response = upload_form.call(metadata, valid_doc)
        missing = missing_key ? 'Missing' : 'Invalid'
        msg = "Metadata Field Error - #{missing} #{key}"
        regex_match = regex_match_expectation.call(msg)
        expect(response.body.strip).to match(regex_match)
        expect(response.status).to eq(412)
      end
    end
    let :valid_metadata do
      lambda do |set_uuid = true|
        metadata = get_fixture('vba_documents/metadata')
        metadata['uuid'] = @uuid if set_uuid
        metadata
      end
    end
    let :upload_form do
      lambda do |metadata, document_path, *attachments|
        metadata_hash = metadata.deep_dup
        attach_hash = {}

        if (!attachments.nil? && attachments&.size) > 0
          metadata_hash['numberAttachments'] = attachments.size unless metadata.frozen?

          attachments.each_with_index do |attach_path, idx|
            attach_hash["attachment#{idx + 1}"] = Faraday::UploadIO.new(attach_path, Mime[:pdf].to_s)
            metadata_hash["numberPages#{idx + 1}"] = 1 unless metadata.frozen?
            metadata_hash["ahash#{idx + 1}"] = 'hash4attachment' unless metadata.frozen?
          end
        end

        upload_hash = {
          metadata: metadata_hash.to_json,
          document: Faraday::UploadIO.new(document_path, Mime[:pdf].to_s)
        }
        described_class.new.upload(upload_hash.merge(attach_hash))
      end
    end

    context 'with an bad response status' do
      it 'increments statsd' do
        expect(service).to receive(:request).and_return(
          OpenStruct.new(success?: false)
        )

        expect { service.upload('metadata' => nil) }.to trigger_statsd_increment('api.central_mail.upload.fail')
      end
    end

    context 'with missing metadata' do
      %w[veteranFirstName veteranLastName fileNumber zipCode].each do |key|
        it "Returns a 412 error when no #{key} is present" do
          VCR.use_cassette(
            "central_mail/bad_metadata_no_#{key}",
            match_requests_on: [multipart_request_matcher, :method, :uri]
          ) do
            metadata = valid_metadata.call
            response_helper.call(metadata.except(key), key)
          end
        end
      end
    end

    context 'with business line metadata' do
      %w[valid blank missing invalid].each do |action|
        test_msg = "Returns successfully when a businessLine key is #{action}"
        resp_msg = 'Request was received successfully'
        status = 200

        if action.eql?('invalid')
          test_msg = "Returns a failure when a businessLine key is #{action}"
          resp_msg = 'Metadata Field Error - Invalid businessLine'
          status = 412
        end

        it test_msg do
          VCR.use_cassette(
            "central_mail/metadata_business_line_#{action}",
            match_requests_on: [multipart_request_matcher, :method, :uri]
          ) do
            key = 'businessLine'
            metadata = valid_metadata.call

            if action.eql? 'invalid'
              metadata[key] = 'INVALID'
            else
              metadata[key] = '' if action.eql? 'blank'
              metadata = metadata.except(key) if action.eql? 'missing'
            end

            response = upload_form.call(metadata, valid_doc)
            regex_match = regex_match_expectation.call(resp_msg)
            expect(response.body.strip).to match(regex_match)
            expect(response.status).to eq(status)
          end
        end
      end
    end

    context 'with invalid metadata' do
      %w[veteranFirstName veteranLastName fileNumber zipCode].each do |key|
        it "Returns a 412 error when #{key} is blank" do
          VCR.use_cassette(
            "central_mail/bad_metadata_blank_#{key}",
            match_requests_on: [multipart_request_matcher, :method, :uri]
          ) do
            metadata = valid_metadata.call
            metadata[key] = '    '
            response_helper.call(metadata, key)
          end
        end

        if ['zipCode'].include?(key)
          it "Returns a 412 error when #{key} is invalid" do
            VCR.use_cassette(
              "central_mail/bad_metadata_invalid_#{key}",
              match_requests_on: [multipart_request_matcher, :method, :uri]
            ) do
              metadata = valid_metadata.call
              metadata[key] = 'invalid_data'
              response_helper.call(metadata, key, false)
            end
          end

          it "Returns a 412 error when #{key} is not enough digits" do
            VCR.use_cassette(
              "central_mail/bad_metadata_less_#{key}_digits",
              match_requests_on: [multipart_request_matcher, :method, :uri]
            ) do
              metadata = valid_metadata.call
              metadata[key] = '111'
              response_helper.call(metadata, key, false)
            end
          end

          it "Returns a 412 error when #{key} is too many digits" do
            VCR.use_cassette(
              "central_mail/bad_metadata_more_#{key}_digits",
              match_requests_on: [multipart_request_matcher, :method, :uri]
            ) do
              metadata = valid_metadata.call
              metadata[key] = '555551'
              response_helper.call(metadata, key, false)
            end
          end
        end
      end
    end

    context 'with a valid upload and invalid attachment numbers metadata' do
      it 'upload fails with main form only' do
        VCR.use_cassette(
          'central_mail/upload_mismatch_error',
          match_requests_on: [multipart_request_matcher, :method, :uri]
        ) do
          metadata = valid_metadata.call
          metadata['numberAttachments'] = 11
          response = upload_form.call(metadata, valid_doc)
          msg = 'Mismatched attachments and numbers'
          regex_match = regex_match_expectation.call(msg)
          expect(response.body.strip).to match(regex_match)
          expect(response.status).to eq(409)
        end
      end

      it 'upload fails with attachments' do
        VCR.use_cassette(
          'central_mail/upload_mismatch_error_attach',
          match_requests_on: [multipart_request_matcher, :method, :uri]
        ) do
          metadata = valid_metadata.call.deep_dup
          metadata['numberPages1'] = 1
          metadata['ahash1'] = 'attachment_hash1'
          metadata['numberPages2'] = 11
          metadata['ahash2'] = 'attachment_hash2'

          response = upload_form.call(metadata.freeze, valid_doc, valid_attach, valid_attach)
          msg = 'Mismatched attachments and numbers'
          regex_match = regex_match_expectation.call(msg)
          expect(response.body.strip).to match(regex_match)
          expect(response.status).to eq(409)
        end
      end
    end

    context 'with a valid file and metadata' do
      it 'upload succeeds with main form only' do
        VCR.use_cassette(
          'central_mail/upload_mainform_only',
          match_requests_on: [multipart_request_matcher, :method, :uri]
        ) do
          metadata = valid_metadata.call
          response = upload_form.call(metadata, valid_doc)
          msg = 'Request was received successfully'
          regex_match = regex_match_expectation.call(msg)
          expect(response.body.strip).to match(regex_match)
          expect(response.status).to eq(200)
        end
      end

      it 'upload succeeds with main form and one attachment' do
        VCR.use_cassette(
          'central_mail/upload_one_attachment',
          match_requests_on: [multipart_request_matcher, :method, :uri]
        ) do
          metadata = valid_metadata.call
          response = upload_form.call(metadata, valid_doc, valid_attach)
          msg = 'Request was received successfully'
          regex_match = regex_match_expectation.call(msg)
          expect(response.body.strip).to match(regex_match)
          expect(response.status).to eq(200)
        end
      end

      it 'upload succeeds with main form and two attachments' do
        VCR.use_cassette(
          'central_mail/upload_two_attachments',
          match_requests_on: [multipart_request_matcher, :method, :uri]
        ) do
          metadata = valid_metadata.call
          response = upload_form.call(metadata, valid_doc, valid_attach, valid_attach)
          msg = 'Request was received successfully'
          regex_match = regex_match_expectation.call(msg)
          expect(response.body.strip).to match(regex_match)
          expect(response.status).to eq(200)
        end
      end

      it 'upload fails when uuid was uploaded previously' do
        VCR.use_cassette(
          'central_mail/upload_duplicate',
          match_requests_on: [multipart_request_matcher, :method, :uri]
        ) do
          uuid = 'a8c29dbc-a0a6-4177-ae57-fc6143ec7edb'
          metadata = valid_metadata.call
          metadata['uuid'] = uuid
          response = upload_form.call(metadata, valid_doc, valid_attach)
          msg = 'Document already uploaded with uuid'
          regex_match = regex_match_expectation.call(msg)
          expect(response.body.strip).to match(regex_match)
          expect(response.status).to eq(400)
        end
      end

      it 'upload succeeds when XXXXX zip code used' do
        VCR.use_cassette(
          'central_mail/upload_XXXXX_zip',
          match_requests_on: [multipart_request_matcher, :method, :uri]
        ) do
          metadata = valid_metadata.call
          metadata['zipCode'] = '47250'
          response = upload_form.call(metadata, valid_doc, valid_attach)
          msg = 'Request was received successfully'
          regex_match = regex_match_expectation.call(msg)
          expect(response.body.strip).to match(regex_match)
          expect(response.status).to eq(200)
        end
      end

      it 'upload succeeds when XXXXX-XXXX zip code used' do
        VCR.use_cassette(
          'central_mail/upload_XXXXX-XXXX_zip',
          match_requests_on: [multipart_request_matcher, :method, :uri]
        ) do
          metadata = valid_metadata.call
          metadata['zipCode'] = '47250-1111'
          response = upload_form.call(metadata, valid_doc, valid_attach)
          msg = 'Request was received successfully'
          regex_match = regex_match_expectation.call(msg)
          expect(response.body.strip).to match(regex_match)
          expect(response.status).to eq(200)
        end
      end
    end

    context 'with a locked pdf' do
      it 'upload fails due to locked main form' do
        VCR.use_cassette(
          'central_mail/upload_locked_main_form',
          match_requests_on: [multipart_request_matcher, :method, :uri]
        ) do
          metadata = valid_metadata.call
          response = upload_form.call(metadata, locked_pdf)
          msg = 'password-protected pdf'
          regex_match = regex_match_expectation.call(msg)
          expect(response.body.strip).to match(regex_match)
          expect(response.status).to eq(422)
        end
      end

      it 'upload fails due to locked attachment' do
        VCR.use_cassette(
          'central_mail/upload_locked_attachment',
          match_requests_on: [multipart_request_matcher, :method, :uri]
        ) do
          metadata = valid_metadata.call
          response = upload_form.call(metadata, valid_doc, locked_pdf)
          msg = 'password-protected PDF \[ locked.pdf \]'
          regex_match = regex_match_expectation.call(msg)
          expect(response.body.strip).to match(regex_match)
          expect(response.status).to eq(422)
        end
      end
    end
  end

  describe '.service_is_up?' do
    context 'when there is no current breakers outage' do
      it 'returns true' do
        expect(described_class.service_is_up?).to be(true)
      end
    end

    context 'when there is a current breakers outage' do
      before do
        Timecop.freeze
        CentralMail::Configuration.instance.breakers_service.begin_forced_outage!
      end

      after { Timecop.return }

      it 'returns false' do
        expect(described_class.service_is_up?).to be(false)
      end
    end
  end
end
