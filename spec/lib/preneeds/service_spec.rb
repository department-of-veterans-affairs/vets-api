# frozen_string_literal: true

require 'rails_helper'
require 'preneeds/service'
require 'vets/collection'

describe Preneeds::Service do
  let(:subject) { described_class.new }
  let(:burial_form) { build(:burial_form) }

  describe 'get_cemeteries' do
    it 'gets a collection of cemeteries' do
      cemeteries = VCR.use_cassette('preneeds/cemeteries/gets_a_list_of_cemeteries') do
        subject.get_cemeteries
      end

      expect(cemeteries).to be_a(Vets::Collection)
      expect(cemeteries.type).to eq(Preneeds::Cemetery)
    end
  end

  describe 'receive_pre_need_application' do
    before do
      FactoryBot.rewind_sequences
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
