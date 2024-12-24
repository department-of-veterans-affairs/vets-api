# frozen_string_literal: true

require 'rails_helper'
require 'va1010_forms/enrollment_system/service'

RSpec.describe VA1010Forms::EnrollmentSystem::Service do
  include SchemaMatchers

  let(:current_user) do
    create(
      :evss_user,
      :loa3,
      icn: '1013032368V065534',
      birth_date: '1986-01-02',
      first_name: 'FirstName',
      middle_name: 'MiddleName',
      last_name: 'ZZTEST',
      suffix: 'Jr.',
      ssn: '111111234',
      gender: 'F'
    )
  end
  let(:user_identifier) do
    {
      'icn' => current_user.icn,
      'edipi' => current_user.edipi
    }
  end
  let(:form) { get_fixture('form1010_ezr/valid_form') }
  let(:ves_fields) do
    {
      'discloseFinancialInformation' => true,
      'isEssentialAcaCoverage' => false,
      'vaMedicalFacility' => '988'
    }
  end
  let(:form_with_ves_fields) { form.merge!(ves_fields) }
  let(:response) do
    double(body: Ox.parse(%(
    <?xml version='1.0' encoding='UTF-8'?>
    <S:Envelope>
      <S:Body>
        <submitFormResponse>
          <status>100</status>
          <formSubmissionId>40124668140</formSubmissionId>
          <message><type>Form successfully received for EE processing</type></message>
          <timeStamp>2016-05-25T04:59:39.345-05:00</timeStamp>
        </submitFormResponse>
      </S:Body>
    </S:Envelope>
     )))
  end

  describe '#submit' do
    before do
      allow(Rails.logger).to receive(:info)
    end

    context 'when no error occurs' do
      it "returns an object that includes 'success', 'formSubmissionId', and 'timestamp'",
        run_at: 'Tue, 21 Nov 2023 20:42:44 GMT' do
        VCR.use_cassette(
          'form1010_ezr/authorized_submit',
          { match_requests_on: %i[method uri body], erb: true }
        ) do
          submission_response = described_class.new(user_identifier).submit(
            form_with_ves_fields,
            '10-10EZR'
          )

          expect(submission_response).to be_a(Object)
          expect(submission_response).to eq(
            {
              success: true,
              formSubmissionId: 436_462_561,
              timestamp: '2024-08-23T13:00:11.005-05:00'
            }
          )
        end
      end

      it "logs the payload size, attachment count, and individual attachment sizes in descending " \
           'order (if applicable)',
        run_at: 'Wed, 17 Jul 2024 18:04:50 GMT' do
        VCR.use_cassette(
          'hca/submit_with_attachment',
          VCR::MATCH_EVERYTHING.merge(erb: true)
        ) do
          described_class.new.submit(
            create(:hca_app_with_attachment).parsed_form,
            '10-10EZ'
          )

          expect(Rails.logger).to have_received(:info).with(
            'Payload for submitted 1010EZ: Body size of 16 KB with 2 attachment(s)'
          )
          expect(Rails.logger).to have_received(:info).with(
            'Attachment sizes in descending order: 1.8 KB, 1.8 KB'
          )
        end
      end
    end

    context 'when an error occurs' do
      before do
        allow_any_instance_of(
          Common::Client::Base
        ).to receive(:perform).and_raise(
          StandardError.new('Uh oh. Some bad error occurred.')
        )
      end

      it 'raises the error' do
        expect {
          described_class.new.submit(
            form_with_ves_fields,
            '10-10EZR'
          )
        }.to raise_error(StandardError, 'Uh oh. Some bad error occurred.')
      end
    end
  end

  describe '#submission_body' do
    let(:user) { FactoryBot.build(:user, :loa3, icn: nil) }

    root = Rails.root.join('spec', 'fixtures', 'hca', 'conformance')

    Dir[File.join(root, '*.json')].map { |f| File.basename(f, '.json') }.each do |form|
      it 'converts the JSON data into a VES-acceptable xml payload', run_at: '2016-12-12' do
        allow_any_instance_of(MPIData).to receive(:icn).and_return('1000123456V123456')

        json = JSON.parse(File.open(root.join("#{form}.json")).read)

        expect(json).to match_vets_schema('10-10EZ')

        xml = File.read(root.join("#{form}.xml"))
        user_identifier = form.match?(/authenticated/) ? HealthCareApplication.get_user_identifier(user) : nil
        formatted = HCA::EnrollmentSystem.veteran_to_save_submit_form(json, user_identifier, '10-10EZ')

        formatted_xml_request = described_class.new(user_identifier).send(:submission_body, formatted)
        pretty_printed =
          Ox.dump(
            Ox.parse(
              formatted_xml_request
            ).locate('soap:Envelope/soap:Body/ns1:submitFormRequest').first
          )

        expect(pretty_printed[1..]).to eq(xml)
      end
    end
  end
end