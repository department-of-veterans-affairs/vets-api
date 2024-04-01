# frozen_string_literal: true

require 'rails_helper'
require 'bgs_service/vnp_person_service'

describe ClaimsApi::VnpPersonService do
  subject { described_class.new external_uid: 'xUid', external_key: 'xKey' }

  # get a proc_id from vnp_proc_create
  # get a ptcpnt_id from vnp_ptcpnt_create (using the proc_id from the previous step)
  let(:vnp_proc_id) { '3854545' }
  let(:vnp_ptcpnt_id) { '182008' }
  let(:expected_response) do
    { vnp_proc_id:, vnp_ptcpnt_id:,
      first_nm: 'Tamara', last_nm: 'Ellis' }
  end

  describe 'vnp_person_create' do
    before do |test|
      unless test.metadata[:skip_name]
        expect_any_instance_of(ClaimsApi::LocalBGS).to receive(:make_request).and_wrap_original do |orig, args|
          body = Hash.from_xml(args[:body].to_s)['arg0']
                     .transform_keys!(&:underscore).deep_symbolize_keys
          expect((expected_response.to_a & body.to_a).to_h).to eq expected_response
          orig.call(**args)
        end
      end
    end

    it 'validates data', :skip_name do
      data = { asdf: 'qwerty' }
      e = an_instance_of(ArgumentError).and having_attributes(
        message: 'Missing required keys: vnpProcId, vnpPtcpntId, firstNm, lastNm'
      )
      expect { subject.vnp_person_create(data) }.to raise_error(e)
    end

    it 'creates a new person from data' do
      data = {
        vnp_proc_id:,
        vnp_ptcpnt_id:,
        first_nm: 'Tamara',
        last_nm: 'Ellis'
      }
      VCR.use_cassette('bgs/vnp_person_service/vnp_person_create') do
        result = subject.vnp_person_create(data)
        expect((expected_response.to_a & result.to_a).to_h).to eq expected_response
      end
    end

    it 'creates a new person from data and target_veteran' do
      data = { vnp_proc_id: }
      target_veteran = OpenStruct.new(
        icn: '1012667145V762142',
        first_name: 'Tamara',
        last_name: 'Ellis',
        loa: { current: 3, highest: 3 },
        edipi: '1005490754',
        ssn: '796130115',
        participant_id: vnp_ptcpnt_id,
        mpi: OpenStruct.new(
          icn: '1012832025V743496',
          profile: OpenStruct.new(ssn: '796130115')
        )
      )
      VCR.use_cassette('bgs/vnp_person_service/vnp_person_create') do
        result = subject.vnp_person_create(data, target_veteran:)
        expect((data.to_a & result.to_a).to_h).to eq data
        expect((expected_response.to_a & result.to_a).to_h).to eq expected_response
      end
    end

    it 'creates a new person from data and icn' do
      profile = MPI::Responses::FindProfileResponse.new(
        status: :ok,
        profile: FactoryBot.build(:mpi_profile,
                                  given_names: ['Tamara'],
                                  family_name: 'Ellis',
                                  participant_id: vnp_ptcpnt_id,
                                  participant_ids: [vnp_ptcpnt_id])
      )
      allow_any_instance_of(MPI::Service).to receive(:find_profile_by_identifier).and_return(profile)

      data = { vnp_proc_id: }
      icn = '1012667145V762142'
      VCR.use_cassette('bgs/vnp_person_service/vnp_person_create') do
        result = subject.vnp_person_create(data, icn:)
        expect((expected_response.to_a & result.to_a).to_h).to eq expected_response
      end
    end
  end
end
