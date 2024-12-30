# frozen_string_literal: true

require 'rails_helper'
require 'gi/lcpe/client'
require 'gi/gids_response'

describe GI::LCPE::Client do
  let(:service) { GI::LCPE::Client.new }

  describe '#get_licenses_and_certs_v1' do
    it 'gets list of licenses and certifications' do
      VCR.use_cassette('gi/lcpe/get_licenses_and_certs_v1') do
        response = service.get_licenses_and_certs_v1({})
        lacs = response.body[:lacs]
        expect(lacs.class).to be(Array)
        expect(lacs.first.keys).to eq(%i[enriched_id name type])
      end
    end
  end

  describe '#get_license_and_cert_details_v1' do
    it 'gets details for license or certification' do
      VCR.use_cassette('gi/lcpe/get_license_and_cert_details_v1') do
        response = service.get_license_and_cert_details_v1({ id: '1@f9822' })
        lac = response.body[:lac]
        expect(lac.class).to be(Hash)
        expect(lac.keys).to eq(%i[enriched_id name type tests institution])
        expect(lac[:tests].class).to be(Array)
        expect(lac[:institution].class).to be(Hash)
      end
    end
  end

  describe '#get_exams_v1' do
    it 'gets list of exams' do
      VCR.use_cassette('gi/lcpe/get_exams_v1') do
        response = service.get_exams_v1({})
        exams = response.body[:exams]
        expect(exams.class).to be(Array)
        expect(exams.first.keys).to eq(%i[enriched_id name])
      end
    end
  end

  describe '#get_exam_details_v1' do
    it 'gets list of exams' do
      VCR.use_cassette('gi/lcpe/get_exam_details_v1') do
        response = service.get_exam_details_v1({ id: '1@acce9' })
        exam = response.body[:exam]
        expect(exam.class).to be(Hash)
        expect(exam.keys).to eq(%i[enriched_id name tests institution])
        expect(exam[:tests].class).to be(Array)
        expect(exam[:institution].class).to be(Hash)
      end
    end
  end
end
