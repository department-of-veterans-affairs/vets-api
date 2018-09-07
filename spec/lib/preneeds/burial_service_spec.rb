# frozen_string_literal: true

require 'rails_helper'
require 'preneeds/service'

describe Preneeds::BurialService do
  let(:subject) { described_class.new }
  let(:burial_form) { build(:burial_form) }

  describe 'receive_pre_need_application' do
    before do
      FactoryBot.rewind_sequences
    end

    context 'with attachments' do
      def match_with_switched_mimeparts(str1, str2, old_mimepart, new_mimepart)
        expect(str1.gsub(new_mimepart, old_mimepart)).to eq(str2)
      end

      it 'creates a preneeds application', run_at: 'Tue, 21 Nov 2017 22:10:32 GMT' do
        multipart_matcher = lambda do |request1, request2|
          new_mimepart = request1.headers['Content-Type'][0].split(';')[1].gsub(' boundary="', '').delete('"')
          old_mimepart = '--==_mimepart_5a14a4580_948e2ab145fb50ec722de'

          expect(request1.headers.keys).to eq(request2.headers.keys)

          request1.headers.each do |k, v|
            next if k == 'Content-Length'

            match_with_switched_mimeparts(v[0], request2.headers[k][0], old_mimepart, new_mimepart)
          end

          match_with_switched_mimeparts(request1.body, request2.body, old_mimepart, new_mimepart)
        end

        expect(SecureRandom).to receive(:hex).twice.and_return(
          '51470ddbd16aa72e52128a84b4cc08a7',
          '1aaca735a4f6ea900ef0617b770ead26'
        )
        expect_any_instance_of(Preneeds::BurialForm).to receive(:generate_tracking_number).and_return(
          'RqC19rMNJf9nJYm1g0VG'
        )

        VCR.use_cassette(
          'preneeds/burial_forms/burial_form_with_attachments',
          match_requests_on: [multipart_matcher, :uri, :method]
        ) do
          subject.receive_pre_need_application(burial_form)
        end
      end
    end

    context 'with no attachments' do
      it 'creates a preneeds application', run_at: 'Tue, 21 Nov 2017 23:03:55 GMT' do
        expect_any_instance_of(Preneeds::BurialForm).to receive(:generate_tracking_number).and_return(
          'J1g4L0d13DrkhM0TpdVG'
        )
        allow(burial_form).to receive(:preneed_attachments).and_return([])

        application = VCR.use_cassette(
          'preneeds/burial_forms/creates_a_pre_need_burial_form',
          match_requests_on: %i[method uri body headers]
        ) do
          subject.receive_pre_need_application burial_form
        end

        expect(application).to be_a(Preneeds::ReceiveApplication)
      end
    end
  end

  describe 'build_multipart' do
    it 'should build a multipart request' do
      multipart = subject.send(:build_multipart, double(body: 'foo'), burial_form.attachments)
      expect(multipart.body.parts.map(&:content_type)).to eq(
        [
          'application/xop+xml; charset=UTF-8; type="text/xml"',
          'application/pdf',
          'application/pdf'
        ]
      )
    end
  end
end
