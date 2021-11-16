# frozen_string_literal: true

require 'rails_helper'
require 'preneeds/service'

describe Preneeds::Service do
  let(:subject) { described_class.new }
  let(:burial_form) { build(:burial_form) }

  describe 'get_cemeteries' do
    it 'gets a collection of cemeteries' do
      cemeteries = VCR.use_cassette('preneeds/cemeteries/gets_a_list_of_cemeteries') do
        subject.get_cemeteries
      end

      expect(cemeteries).to be_a(Common::Collection)
      expect(cemeteries.type).to eq(Preneeds::Cemetery)
    end
  end

  describe 'receive_pre_need_application' do
    before do
      FactoryBot.rewind_sequences
    end

    context 'with attachments' do
      def match_with_switched_mimeparts(str1, str2, old_mimepart, new_mimepart)
        a = str1.gsub(new_mimepart, old_mimepart)

        expect(a).to eq(str2)
      end

      it 'creates a preneeds application', run_at: 'Thu, 13 Aug 2020 03:28:26 GMT' do
        multipart_matcher = lambda do |request_1, request_2|
          new_mimepart = request_1.headers['Content-Type'][0].split(';')[1].gsub(' boundary="', '').delete('"')
          old_mimepart = '--==_mimepart_5f34b35a5e675_690ae7d998184a8'

          expect(request_1.headers.keys).to eq(request_2.headers.keys)

          request_1.headers.each do |k, v|
            next if k == 'Content-Length'

            match_with_switched_mimeparts(v[0], request_2.headers[k][0], old_mimepart, new_mimepart)
          end

          match_with_switched_mimeparts(request_1.body, request_2.body, old_mimepart, new_mimepart)
        end

        expect(SecureRandom).to receive(:hex).twice.and_return(
          '10da04424190066fc1bb1fd6955008a4',
          '8734786de1fa56dafaef5a9f04beaed8'
        )
        expect_any_instance_of(Preneeds::BurialForm).to receive(:generate_tracking_number).and_return(
          'L46JGnr0DL2bqUXS9EVG'
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
      it 'creates a preneeds application', run_at: 'Thu, 13 Aug 2020 03:25:19 GMT' do
        expect_any_instance_of(Preneeds::BurialForm).to receive(:generate_tracking_number).and_return(
          'u6HaIsaeE5DodpGD8nVG'
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

    context 'with foreign address' do
      let(:burial_form_foreign_address) { build(:burial_form_foreign_address) }

      it 'includes the <state> attribute in the request XML' do
        client = Savon.client(wsdl: Settings.preneeds.wsdl)
        soap = client.build_request(
          :receive_pre_need_application,
          message: {
            pre_need_request: burial_form_foreign_address.as_eoas
          }
        )
        expect(soap.body).to match(%r{</postalZip><state></state>})
      end
    end
  end

  describe 'build_multipart' do
    it 'builds a multipart request' do
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
