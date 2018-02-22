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

  describe 'get_states' do
    it 'gets a collection of states' do
      states = VCR.use_cassette('preneeds/states/gets_a_list_of_states') do
        subject.get_states
      end

      expect(states).to be_a(Common::Collection)
      expect(states.type).to eq(Preneeds::State)
    end
  end

  describe 'get_discharge_types' do
    it 'gets a collection of discharge_types' do
      discharge_types = VCR.use_cassette('preneeds/discharge_types/gets_a_list_of_discharge_types') do
        subject.get_discharge_types
      end

      expect(discharge_types).to be_a(Common::Collection)
      expect(discharge_types.type).to eq(Preneeds::DischargeType)
    end
  end

  describe 'get_attachment_types' do
    it 'gets a collection of attachment_types' do
      attachment_types = VCR.use_cassette('preneeds/attachment_types/gets_a_list_of_attachment_types') do
        subject.get_attachment_types
      end

      expect(attachment_types).to be_a(Common::Collection)
      expect(attachment_types.type).to eq(Preneeds::AttachmentType)
    end
  end

  describe 'get_branches_of_service' do
    it 'gets a collection of service branches' do
      branches = VCR.use_cassette('preneeds/branches_of_service/gets_a_list_of_service_branches') do
        subject.get_branches_of_service
      end

      expect(branches).to be_a(Common::Collection)
      expect(branches.type).to eq(Preneeds::BranchesOfService)
    end
  end

  describe 'get_military_rank_for_branch_of_service' do
    let(:params) do
      { branch_of_service: 'AC', start_date: '1926-07-02', end_date: '1926-07-02' }
    end

    it 'gets a collection of service branches' do
      ranks = VCR.use_cassette('preneeds/military_ranks/gets_a_list_of_military_ranks') do
        subject.get_military_rank_for_branch_of_service params
      end

      expect(ranks).to be_a(Common::Collection)
      expect(ranks.type).to eq(Preneeds::MilitaryRank)
    end
  end

  describe 'receive_pre_need_application' do
    before do
      FactoryBot.rewind_sequences
    end

    context 'with attachments' do
      def match_with_switched_mimeparts(str1, str2, old_mimepart, new_mimepart)
        expect(str1.gsub(new_mimepart, old_mimepart)).to eq(str2)
      end

      it 'creates a preneeds application', run_at: 'Tue, 21 Nov 2017 22:10:32 GMT' do
        multipart_matcher = lambda do |request_1, request_2|
          new_mimepart = request_1.headers['Content-Type'][0].split(';')[1].gsub(' boundary="', '').delete('"')
          old_mimepart = '--==_mimepart_5a14a4580_948e2ab145fb50ec722de'

          expect(request_1.headers.keys).to eq(request_2.headers.keys)

          request_1.headers.each do |k, v|
            next if k == 'Content-Length'

            match_with_switched_mimeparts(v[0], request_2.headers[k][0], old_mimepart, new_mimepart)
          end

          match_with_switched_mimeparts(request_1.body, request_2.body, old_mimepart, new_mimepart)
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
