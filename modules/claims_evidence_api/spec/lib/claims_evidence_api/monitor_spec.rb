# frozen_string_literal: true

require 'rails_helper'
require 'claims_evidence_api/monitor'

RSpec.describe ClaimsEvidenceApi::Monitor do
  let(:base) { ClaimsEvidenceApi::Monitor.new }
  let(:record) { ClaimsEvidenceApi::Monitor::Record.new(build(:claims_evidence_submission)) }
  let(:service) { ClaimsEvidenceApi::Monitor::Service.new }
  let(:uploader) { ClaimsEvidenceApi::Monitor::Uploader.new }

  context 'base monitor functions' do
    describe '#format_message' do
      it 'returns message preceded by class name' do
        msg = base.format_message('TEST')
        expect(msg).to eq "#{subject.class}: TEST"
      end
    end

    describe '#format_tags' do
      it 'returns message preceded by class name' do
        tags = { foo: :bar, 'test' => 23 }
        tags = base.format_tags(tags)
        expect(tags).to eq ['foo:bar', 'test:23']
      end
    end
  end

  context 'Record monitor functions' do
    let(:metric) { ClaimsEvidenceApi::Monitor::Record::METRIC }

    describe '#track_event' do
      it 'tracks the record action and attributes' do
        action = :test_event
        message = "#{record.class}: #{record.record.class} #{action}"
        tags = ["class:#{record.record.class.to_s.downcase.gsub(/:+/, '_')}", "action:#{action}"]
        attributes = { foo: :bar, 'test' => 23 }

        expect(record).to receive(:track_request).with(:info, message, metric, tags:, **attributes)

        record.track_event(action, **attributes)
      end
    end
  end

  context 'Service monitor functions' do
    let(:metric) { ClaimsEvidenceApi::Monitor::Service::METRIC }

    describe '#track_api_request' do
      it 'tracks an OK request' do
        path = 'test/path/requested'
        code = 210
        reason = 'testing ok'
        call_location = 'foobar'

        tags = { method: :get, code:, root: path.split('/').first }
        formatted_tags = ['method:get', 'code:210', 'root:test']
        message = "#{service.class}: #{code} #{reason}"

        kwargs = { call_location:, path:, reason:, tags: formatted_tags, **tags }
        expect(service).to receive(:track_request).with(:info, message, metric, **kwargs)

        service.track_api_request(:get, path, code, reason, call_location:)
      end

      it 'tracks an Error request' do
        path = 'test/path/requested'
        code = 404
        reason = 'testing 404'
        call_location = 'foobar'

        tags = { method: :get, code:, root: path.split('/').first }
        formatted_tags = ['method:get', 'code:404', 'root:test']
        message = "#{service.class}: #{code} #{reason}"

        kwargs = { call_location:, path:, reason:, tags: formatted_tags, **tags }
        expect(service).to receive(:track_request).with(:error, message, metric, **kwargs)

        service.track_api_request(:get, path, code, reason, call_location:)
      end
    end
  end

  context 'Uploader monitor functions' do
    let(:metric) { ClaimsEvidenceApi::Monitor::Uploader::METRIC }
    let(:context) { { foo: :bar, test: 23 } }

    describe '#track_upload' do
      # track_request(level, msg, METRIC, call_location:, message:, tags:, **context)
      %i[begun attempt success].each do |action|
        it "tracks #{action}" do
          message = "#{uploader.class}: upload #{action}"
          tags = ["action:#{action}"]

          kwargs = { call_location: anything, message: nil, tags:, **context }
          expect(uploader).to receive(:track_upload).and_call_original
          expect(uploader).to receive(:track_request).with(:info, message, metric, **kwargs)

          uploader.send("track_upload_#{action}", **context)
        end
      end

      it 'tracks failure' do
        action = :failure
        message = 'TESTING FAILURE'
        msg = "#{uploader.class}: upload #{action} - ERROR #{message}"
        tags = ["action:#{action}"]

        kwargs = { call_location: anything, message: "ERROR #{message}", tags:, **context }
        expect(uploader).to receive(:track_upload).and_call_original
        expect(uploader).to receive(:track_request).with(:error, msg, metric, **kwargs)

        uploader.track_upload_failure(message, **context)
      end
    end
  end
end
