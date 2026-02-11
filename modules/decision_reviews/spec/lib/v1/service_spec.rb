# frozen_string_literal: true

require './modules/decision_reviews/spec/dr_spec_helper'
require './modules/decision_reviews/spec/support/vcr_helper'
require 'decision_reviews/v1/service'

describe DecisionReviews::V1::Service do
  subject { described_class.new }

  let(:ssn_with_mockdata) { '212222112' }
  let(:user) { build(:user, :loa3, ssn: ssn_with_mockdata) }

  describe 'VetsJsonSchema used in service' do
    describe 'ensure Contestable Issues schemas are present' do
      %w[
        DECISION-REVIEW-GET-CONTESTABLE-ISSUES-RESPONSE-200_V1
      ].each do |schema_name|
        it("#{schema_name} schema is present") { expect(VetsJsonSchema::SCHEMAS[schema_name]).to be_a Hash }
      end
    end

    describe 'ensure Contestable Issues schema examples are present' do
      %w[
        DECISION-REVIEW-GET-CONTESTABLE-ISSUES-RESPONSE-200_V1
      ].each do |schema_name|
        it("#{schema_name} schema example is present") { expect(VetsJsonSchema::EXAMPLES).to have_key schema_name }
      end
    end

    describe 'ensure HLR schemas are present' do
      %w[
        HLR-GET-CONTESTABLE-ISSUES-REQUEST-BENEFIT-TYPE_V1
        HLR-CREATE-REQUEST-BODY_V1
        HLR-CREATE-RESPONSE-200_V1
        HLR-SHOW-RESPONSE-200_V2
      ].each do |schema_name|
        it("#{schema_name} schema is present") { expect(VetsJsonSchema::SCHEMAS[schema_name]).to be_a Hash }
      end
    end

    describe 'ensure HLR schema examples are present' do
      %w[
        HLR-CREATE-REQUEST-BODY_V1
      ].each do |schema_name|
        it("#{schema_name} schema example is present") { expect(VetsJsonSchema::EXAMPLES).to have_key schema_name }
      end
    end

    describe 'ensure NOD schemas are present' do
      %w[
        NOD-CREATE-REQUEST-BODY_V1
        NOD-CREATE-RESPONSE-200_V1
        NOD-SHOW-RESPONSE-200_V2
      ].each do |schema_name|
        it("#{schema_name} schema is present") { expect(VetsJsonSchema::SCHEMAS).to have_key schema_name }
      end
    end

    describe 'ensure NOD schema examples are present' do
      %w[
        NOD-CREATE-REQUEST-BODY_V1
      ].each do |schema_name|
        it("#{schema_name} schema example is present") { expect(VetsJsonSchema::EXAMPLES).to have_key schema_name }
      end
    end

    describe 'ensure SC schemas are present' do
      %w[
        SC-GET-CONTESTABLE-ISSUES-REQUEST-BENEFIT-TYPE_V1
        SC-CREATE-REQUEST-BODY_V1
        SC-CREATE-RESPONSE-200_V1
        SC-CREATE-REQUEST-BODY-FOR-VA-GOV
        SC-SHOW-RESPONSE-200_V2
      ].each do |schema_name|
        it("#{schema_name} schema is present") { expect(VetsJsonSchema::SCHEMAS).to have_key schema_name }
      end
    end

    describe 'ensure SC schema examples are present' do
      %w[
        SC-CREATE-REQUEST-BODY_V1
      ].each do |schema_name|
        it("#{schema_name} schema example is present") { expect(VetsJsonSchema::EXAMPLES).to have_key schema_name }
      end
    end
  end

  describe '#create_higher_level_review_headers' do
    subject { described_class.new.send(:create_higher_level_review_headers, user) }

    let(:user) do
      name = 'x' * 100
      build(:user, first_name: name, middle_name: name, last_name: name)
    end

    it 'returns a properly formatted 200 response' do
      expect(subject['X-VA-First-Name']).to eq 'x' * 12
      expect(subject['X-VA-Middle-Initial']).to eq 'X'
      expect(subject['X-VA-Last-Name']).to eq 'x' * 18
    end
  end

  describe '#file_upload_metadata' do
    let(:backup_zip) { '12345' }
    let(:zip_replacement_value) { '00000' }

    context 'with all data present' do
      it 'generates metadata' do
        md = DecisionReviews::V1::Service.file_upload_metadata(user)
        expect(JSON.parse(md).symbolize_keys).to eq({
                                                      veteranFirstName: 'abraham',
                                                      veteranLastName: 'lincoln',
                                                      zipCode: '20500',
                                                      fileNumber: '212222112',
                                                      source: 'va.gov',
                                                      businessLine: 'BVA'
                                                    })
      end
    end

    context 'with a null postal code' do
      it 'generates metadata, with replaced zip and no errors' do
        allow_any_instance_of(User).to receive(:postal_code).and_return(nil)
        md = DecisionReviews::V1::Service.file_upload_metadata(user)
        expect(JSON.parse(md)['zipCode']).to eq(zip_replacement_value)
      end
    end

    context 'with invalid postal codes' do
      ['', '1234', '12345-123', 123, '1' * 100].each do |invalid_zip|
        it "generates metadata with invalid postal code (#{invalid_zip}) provided" do
          allow_any_instance_of(User).to receive(:postal_code).and_return(invalid_zip)
          md = DecisionReviews::V1::Service.file_upload_metadata(user)
          expect(JSON.parse(md)['zipCode']).to eq(zip_replacement_value)
        end
      end
    end

    context 'with backup postal codes' do
      it 'generates metadata without using backup zip if postal code is valid' do
        md = DecisionReviews::V1::Service.file_upload_metadata(user, backup_zip)
        expect(JSON.parse(md)['zipCode']).to eq('20500')
      end

      it 'generates metadata using backup zip if postal code is invalid' do
        backup_zip = '12345'
        allow_any_instance_of(User).to receive(:postal_code).and_return('1234')
        md = DecisionReviews::V1::Service.file_upload_metadata(user, backup_zip)
        expect(JSON.parse(md)['zipCode']).to eq(backup_zip)
      end
    end
  end

  describe '#create_higher_level_review' do
    subject { described_class.new.create_higher_level_review(request_body: body.to_json, user:) }

    let(:body) { VetsJsonSchema::EXAMPLES['HLR-CREATE-REQUEST-BODY_V1'] }

    context '200 response' do
      it 'returns a properly formatted 200 response' do
        VCR.use_cassette('decision_review/HLR-CREATE-RESPONSE-200_V1') do
          expect(subject).to respond_to :status
          expect(subject.status).to be 200
          expect(subject).to respond_to :body
          expect(subject.body).to be_a Hash
        end
      end
    end

    context '422 response' do
      let(:body) { {} }

      it 'throws a Common::Exception' do
        VCR.use_cassette('decision_review/HLR-CREATE-RESPONSE-422_V1') do
          expect { subject }.to raise_error Common::Exceptions::UnprocessableEntity
        end
      end
    end

    # test that additional error code mapping in exceptions.en.yml works
    context '503 response' do
      it 'throws a Common::Exception' do
        VCR.use_cassette('decision_review/HLR-CREATE-RESPONSE-503_V1') do
          expect { subject }.to raise_error Common::Exceptions::ServiceUnavailable
        end
      end
    end

    context '418 response (unmapped error code)' do
      let(:body) { {} }

      it 'throws a DecisionReviews::V1::ServiceException with DR_418 key' do
        VCR.use_cassette('decision_review/HLR-CREATE-RESPONSE-418_V1') do
          expect { subject }.to raise_error do |error|
            expect(error).to be_a(DecisionReviews::V1::ServiceException)
            expect(error.key).to eq('DR_418')
            expect(error.original_status).to eq(418)
          end
        end
      end
    end

    context 'parsing error' do
      it 'throws a DecisionReviews::V1::ServiceException with DR_502 key' do
        allow_any_instance_of(DecisionReviews::V1::Service).to receive(:perform)
          .and_raise(Faraday::ParsingError.new('Invalid JSON'))

        expect { subject }.to raise_error do |error|
          expect(error).to be_a(DecisionReviews::V1::ServiceException)
          expect(error.key).to eq('DR_502')
        end
      end
    end

    context 'user is missing data' do
      before do
        allow_any_instance_of(User).to receive(:ssn).and_return(nil)
      end

      it 'throws a Common::Exceptions::Forbidden exception' do
        expect { subject }.to raise_error Common::Exceptions::Forbidden
      end
    end
  end

  describe '#get_higher_level_review' do
    subject { described_class.new.get_higher_level_review(uuid) }

    let(:uuid) { '75f5735b-c41d-499c-8ae2-ab2740180254' }

    context '200 response' do
      it 'returns a properly formatted 200 response' do
        VCR.use_cassette('decision_review/HLR-SHOW-RESPONSE-200_V2') do
          expect(subject).to respond_to :status
          expect(subject.status).to be 200
          expect(subject).to respond_to :body
          expect(subject.body).to be_a Hash
        end
      end
    end

    context '404 response' do
      let(:uuid) { '0' }

      it 'throws a Common::Exception' do
        VCR.use_cassette('decision_review/HLR-SHOW-RESPONSE-404_V1') do
          expect { subject }.to raise_error Common::Exceptions::ResourceNotFound
        end
      end
    end
  end

  describe '#get_higher_level_review_contestable_issues' do
    subject do
      described_class.new.get_higher_level_review_contestable_issues(benefit_type:, user:)
    end

    let(:benefit_type) { 'compensation' }

    context '200 response' do
      it 'returns a properly formatted 200 response' do
        VCR.use_cassette('decision_review/HLR-GET-CONTESTABLE-ISSUES-RESPONSE-200_V1') do
          expect(subject).to respond_to :status
          expect(subject.status).to be 200
          expect(subject).to respond_to :body
          expect(subject.body).to be_a Hash
        end
      end
    end

    context '200 response with a malformed body' do
      def personal_information_logs
        PersonalInformationLog.where error_class: 'DecisionReviews::V1::Service#validate_against_schema' \
                                                  ' exception Common::Exceptions::SchemaValidationErrors (HLR_V1)'
      end

      it 'returns a schema error' do
        VCR.use_cassette('decision_review/HLR-GET-CONTESTABLE-ISSUES-RESPONSE-200-MALFORMED_V1') do
          expect(personal_information_logs.count).to be 0
          expect { subject }.to raise_error an_instance_of Common::Exceptions::SchemaValidationErrors
          expect(personal_information_logs.count).to be 1
        end
      end
    end

    context '404 response' do
      before do
        allow_any_instance_of(User).to receive(:ssn).and_return('000000000')
      end

      it 'throws a Common::Exception' do
        VCR.use_cassette('decision_review/HLR-GET-CONTESTABLE-ISSUES-RESPONSE-404_V1') do
          expect { subject }.to raise_error Common::Exceptions::ResourceNotFound
        end
      end
    end

    context '422 response' do
      let(:benefit_type) { 'apricot' }

      it 'throws a Common::Exception' do
        VCR.use_cassette('decision_review/HLR-GET-CONTESTABLE-ISSUES-RESPONSE-422_V1') do
          expect { subject }.to raise_error Common::Exceptions::UnprocessableEntity
        end
      end
    end
  end

  describe '#create_notice_of_disagreement' do
    subject { described_class.new.create_notice_of_disagreement(request_body: body.to_json, user:) }

    let(:body) do
      full_body = VetsJsonSchema::EXAMPLES['NOD-CREATE-REQUEST-BODY_V1']
      full_body.delete('nodUploads')
      full_body
    end

    context '200 response' do
      it 'returns a properly formatted 200 response' do
        VCR.use_cassette('decision_review/NOD-CREATE-RESPONSE-200_V1') do
          expect(subject).to respond_to :status
          expect(subject.status).to be 200
          expect(subject).to respond_to :body
          expect(subject.body).to be_a Hash
        end
      end
    end

    context '422 response' do
      let(:body) { {} }

      it 'throws a Common::Exception' do
        VCR.use_cassette('decision_review/NOD-CREATE-RESPONSE-422_V1') do
          expect { subject }.to raise_error Common::Exceptions::UnprocessableEntity
        end
      end
    end

    context 'user is missing data' do
      before do
        allow_any_instance_of(User).to receive(:ssn).and_return(nil)
      end

      it 'throws a Common::Exceptions::Forbidden exception' do
        expect { subject }.to raise_error Common::Exceptions::Forbidden
      end
    end
  end

  describe '#get_notice_of_disagreement' do
    subject { described_class.new.get_notice_of_disagreement(uuid) }

    let(:uuid) { '1234567a-89b0-123c-d456-789e01234f56' }

    context '200 response' do
      it 'returns a properly formatted 200 response' do
        VCR.use_cassette('decision_review/NOD-SHOW-RESPONSE-200_V2') do
          expect(subject).to respond_to :status
          expect(subject.status).to be 200
          expect(subject).to respond_to :body
          expect(subject.body).to be_a Hash
        end
      end
    end

    context '404 response' do
      let(:uuid) { '0' }

      it 'throws a Common::Exception' do
        VCR.use_cassette('decision_review/NOD-SHOW-RESPONSE-404_V1') do
          expect { subject }.to raise_error Common::Exceptions::ResourceNotFound
        end
      end
    end
  end

  describe '#get_notice_of_disagreement_contestable_issues' do
    subject do
      described_class.new.get_notice_of_disagreement_contestable_issues(user:)
    end

    context '200 response' do
      it 'returns a properly formatted 200 response' do
        VCR.use_cassette('decision_review/NOD-GET-CONTESTABLE-ISSUES-RESPONSE-200_V1') do
          expect(subject).to respond_to :status
          expect(subject.status).to be 200
          expect(subject).to respond_to :body
          expect(subject.body).to be_a Hash
        end
      end
    end

    context '200 response with a malformed body' do
      def personal_information_logs
        PersonalInformationLog.where error_class: 'DecisionReviews::V1::Service#validate_against_schema' \
                                                  ' exception Common::Exceptions::SchemaValidationErrors (NOD_V1)'
      end

      it 'returns a schema error' do
        VCR.use_cassette('decision_review/NOD-GET-CONTESTABLE-ISSUES-RESPONSE-200-MALFORMED_V1') do
          expect(personal_information_logs.count).to be 0
          expect { subject }.to raise_error an_instance_of Common::Exceptions::SchemaValidationErrors
          expect(personal_information_logs.count).to be 1
        end
      end
    end

    context '404 response' do
      before do
        allow_any_instance_of(User).to receive(:ssn).and_return('000000000')
      end

      it 'throws a Common::Exception' do
        VCR.use_cassette('decision_review/NOD-GET-CONTESTABLE-ISSUES-RESPONSE-404_V1') do
          expect { subject }.to raise_error Common::Exceptions::ResourceNotFound
        end
      end
    end
  end

  describe '#get_notice_of_disagreement_upload_url' do
    subject do
      described_class.new.get_notice_of_disagreement_upload_url(nod_uuid: uuid, file_number: ssn_with_mockdata)
    end

    context '200 response' do
      let(:uuid) { 'e076ea91-6b99-4912-bffc-a8318b9b403f' }

      it 'returns a properly formatted 200 response' do
        VCR.use_cassette('decision_review/NOD-GET-UPLOAD-URL-200_V1') do
          expect(subject.status).to be 200
          expect(subject).to respond_to :body
          expect(subject.body).to be_a Hash
        end
      end
    end

    context '404 response' do
      let(:uuid) { 'this-id-not-found' }

      it 'throws a Common::Exception' do
        VCR.use_cassette('decision_review/NOD-GET-UPLOAD-URL-404_V1') do
          expect { subject }.to raise_error Common::Exceptions::ResourceNotFound
        end
      end
    end
  end

  describe '#put_notice_of_disagreement_upload' do
    subject do
      described_class.new.put_notice_of_disagreement_upload(upload_url: path, file_upload:,
                                                            metadata_string: metadata)
    end

    let(:file_upload) do
      double(CarrierWave::SanitizedFile,
             filename: 'upload.pdf',
             read: File.read('spec/fixtures/files/doctors-note.pdf'),
             content_type: Mime[:pdf].to_s)
    end
    let(:path) do
      'https://sandbox-api.va.gov/services_user_content/vba_documents/832a96ca-4dbd-4138-b7a4-6a991ff76faf?X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Credential=AKIAQD72FDTFWPUWR5OZ%2F20210521%2Fus-gov-west-1%2Fs3%2Faws4_request&X-Amz-Date=20210521T193313Z&X-Amz-Expires=900&X-Amz-SignedHeaders=host&X-Amz-Signature=5d64a8a7fd749b1fb301a43226d45cc865fb68e6397026bdf047737c05fa4927'
    end
    let(:metadata) { DecisionReviews::V1::Service.file_upload_metadata(user) }

    context '200 response' do
      it 'returns a properly formatted 200 response' do
        VCR.use_cassette('decision_review/NOD-PUT-UPLOAD-200_V1') do
          expect(subject.status).to be 200
        end
      end
    end
  end

  describe '#get_notice_of_disagreement_upload' do
    subject do
      described_class.new.get_notice_of_disagreement_upload(guid:)
    end

    let(:guid) { '59cdb98f-f94b-4aaa-8952-4d1e59b6e40a' }

    context '200 response' do
      it 'returns a properly formatted 200 response' do
        VCR.use_cassette('decision_review/NOD-GET-UPLOAD-200_V1') do
          expect(subject.status).to be 200
          expect(subject.body.dig('data', 'attributes', 'status')).to eq 'received'
        end
      end
    end
  end

  describe '#create_supplemental_claims_headers' do
    subject { described_class.new.send(:create_supplemental_claims_headers, user) }

    let(:user) do
      build(:user, first_name: 'John', middle_name: 'S', last_name: 'Smith', birth_date: '1980-12-12', ssn: '123456789')
    end

    it 'returns a properly formatted 200 response' do
      expect(subject['X-VA-First-Name']).to eq 'John'
      expect(subject['X-VA-Middle-Initial']).to eq 'S'
      expect(subject['X-VA-Last-Name']).to eq 'Smith'
      expect(subject['X-VA-SSN']).to eq '123456789'
      expect(subject['X-VA-Birth-Date']).to eq '1980-12-12'
    end
  end

  describe '#create_supplemental_claim' do
    subject { described_class.new.create_supplemental_claim(request_body: body.to_json, user:) }

    let(:body) { VetsJsonSchema::EXAMPLES['SC-CREATE-REQUEST-BODY_V1'] }

    context '200 response' do
      it 'returns a properly formatted 200 response' do
        VCR.use_cassette('decision_review/SC-CREATE-RESPONSE-200_V1') do
          expect(subject).to respond_to :status
          expect(subject.status).to be 200
          expect(subject).to respond_to :body
          expect(subject.body).to be_a Hash
        end
      end
    end

    context '422 response' do
      let(:body) { {} }

      it 'throws a Common::Exception' do
        VCR.use_cassette('decision_review/SC-CREATE-RESPONSE-422_V1') do
          expect { subject }.to raise_error Common::Exceptions::UnprocessableEntity
        end
      end
    end

    context 'user is missing data' do
      before do
        allow_any_instance_of(User).to receive(:ssn).and_return(nil)
      end

      it 'throws a Common::Exceptions::Forbidden exception' do
        expect { subject }.to raise_error Common::Exceptions::Forbidden
      end
    end
  end

  describe '#get_supplemental_claim' do
    subject { described_class.new.get_supplemental_claim(uuid) }

    let(:uuid) { '75f5735b-c41d-499c-8ae2-ab2740180254' }

    context '200 response' do
      it 'returns a properly formatted 200 response' do
        VCR.use_cassette('decision_review/SC-SHOW-RESPONSE-200_V2') do
          expect(subject).to respond_to :status
          expect(subject.status).to be 200
          expect(subject).to respond_to :body
          expect(subject.body).to be_a Hash
        end
      end
    end

    context '404 response' do
      let(:uuid) { '0' }

      it 'throws a Common::Exception' do
        VCR.use_cassette('decision_review/SC-SHOW-RESPONSE-404_V1') do
          expect { subject }.to raise_error Common::Exceptions::ResourceNotFound
        end
      end
    end
  end

  describe '#get_supplemental_claim_contestable_issues' do
    subject do
      described_class.new.get_supplemental_claim_contestable_issues(user:, benefit_type:)
    end

    let(:benefit_type) { 'compensation' }

    context '200 response' do
      it 'returns a properly formatted 200 response' do
        VCR.use_cassette('decision_review/SC-GET-CONTESTABLE-ISSUES-RESPONSE-200_V1') do
          expect(subject).to respond_to :status
          expect(subject.status).to be 200
          expect(subject).to respond_to :body
          expect(subject.body).to be_a Hash
        end
      end
    end

    context '200 response with a malformed body' do
      def personal_information_logs
        PersonalInformationLog.where error_class: 'DecisionReviews::V1::Service#validate_against_schema' \
                                                  ' exception Common::Exceptions::SchemaValidationErrors (SC_V1)'
      end

      it 'returns a schema error' do
        VCR.use_cassette('decision_review/SC-GET-CONTESTABLE-ISSUES-RESPONSE-200-MALFORMED_V1') do
          expect(personal_information_logs.count).to be 0
          expect { subject }.to raise_error an_instance_of Common::Exceptions::SchemaValidationErrors
          expect(personal_information_logs.count).to be 1
        end
      end
    end

    context '404 response' do
      before do
        allow_any_instance_of(User).to receive(:ssn).and_return('000000000')
      end

      it 'throws a Common::Exception' do
        VCR.use_cassette('decision_review/SC-GET-CONTESTABLE-ISSUES-RESPONSE-404_V1') do
          expect { subject }.to raise_error Common::Exceptions::ResourceNotFound
        end
      end
    end

    context '422 response' do
      let(:benefit_type) { 'apricot' }

      it 'throws a Common::Exception' do
        VCR.use_cassette('decision_review/SC-GET-CONTESTABLE-ISSUES-RESPONSE-422_V1') do
          expect { subject }.to raise_error Common::Exceptions::UnprocessableEntity
        end
      end
    end
  end

  describe '#get_supplemental_claim_upload_url' do
    subject do
      described_class.new.get_supplemental_claim_upload_url(sc_uuid: uuid, file_number: ssn_with_mockdata)
    end

    context '200 response' do
      let(:uuid) { 'e076ea91-6b99-4912-bffc-a8318b9b403f' }

      it 'returns a properly formatted 200 response' do
        VCR.use_cassette('decision_review/SC-GET-UPLOAD-URL-200_V1') do
          expect(subject.status).to be 200
          expect(subject).to respond_to :body
          expect(subject.body).to be_a Hash
        end
      end
    end

    context '404 response' do
      let(:uuid) { 'this-id-not-found' }

      it 'throws a Common::Exception' do
        VCR.use_cassette('decision_review/SC-GET-UPLOAD-URL-404_V1') do
          expect { subject }.to raise_error Common::Exceptions::ResourceNotFound
        end
      end
    end
  end

  describe '#put_supplemental_claim_upload' do
    subject do
      described_class.new.put_supplemental_claim_upload(upload_url: path, file_upload:,
                                                        metadata_string: metadata)
    end

    let(:file_upload) do
      double(CarrierWave::SanitizedFile,
             filename: 'upload.pdf',
             read: File.read('spec/fixtures/files/doctors-note.pdf'),
             content_type: Mime[:pdf].to_s)
    end
    let(:path) do
      'https://sandbox-api.va.gov/services_user_content/vba_documents/832a96ca-4dbd-4138-b7a4-6a991ff76faf?X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Credential=AKIAQD72FDTFWPUWR5OZ%2F20210521%2Fus-gov-west-1%2Fs3%2Faws4_request&X-Amz-Date=20210521T193313Z&X-Amz-Expires=900&X-Amz-SignedHeaders=host&X-Amz-Signature=5d64a8a7fd749b1fb301a43226d45cc865fb68e6397026bdf047737c05fa4927'
    end
    let(:metadata) { DecisionReviews::V1::Service.file_upload_metadata(user) }

    context '200 response' do
      it 'returns a properly formatted 200 response' do
        VCR.use_cassette('decision_review/SC-PUT-UPLOAD-200_V1') do
          expect(subject.status).to be 200
        end
      end
    end
  end

  describe '#get_supplemental_claim_upload' do
    subject do
      described_class.new.get_supplemental_claim_upload(guid:)
    end

    let(:guid) { '59cdb98f-f94b-4aaa-8952-4d1e59b6e40a' }

    context '200 response' do
      it 'returns a properly formatted 200 response' do
        VCR.use_cassette('decision_review/SC-GET-UPLOAD-200_V1') do
          expect(subject.status).to be 200
          expect(subject.body.dig('data', 'attributes', 'status')).to eq 'received'
        end
      end
    end
  end

  describe '#transliterate_name' do
    subject do
      described_class.transliterate_name(' Andrés 安倍 Guðni Th. Jóhannesson Löfven aaaaaaaaaaaaaabb')
    end

    it 'returns a properly transiterated response' do
      expect(subject).to eq 'Andres  Gudni Th Johannesson Lofven aaaaaaaaaaaaaa'
    end
  end

  describe '#construct_tmpfile_name' do
    subject do
      described_class.new
    end

    it 'returns name with appeal submission upload id when present' do
      result = subject.construct_tmpfile_name(12_345, 'original_filename.pdf')
      expect(result).to eq 'appeal_submission_upload_12345_'
    end

    it 'returns original filename when appeal submission upload id not present' do
      result = subject.construct_tmpfile_name(nil, 'original_filename.pdf')
      expect(result).to eq 'original_filename'
    end

    it 'returns first 240 characters of very long filename as the basename' do
      long_filename = 'Lorem_ipsum_dolor_sit_amet,_consectetur_adipiscing_elit,_sed_do_eiusmod_tempor_' \
                      'incididunt_ut_labore_et_dolore_magna_aliqua_Ut_enim_ad_minim_veniam_quis_nostrud_' \
                      'exercitation_ullamco_laboris_nisi_ut_aliquip_ex_ea_commodo_consequat_Duis_' \
                      'aute_irure_blah.pdf'
      result = subject.construct_tmpfile_name(nil, long_filename)
      expect(result).to eq long_filename.first(240)
    end
  end
end
