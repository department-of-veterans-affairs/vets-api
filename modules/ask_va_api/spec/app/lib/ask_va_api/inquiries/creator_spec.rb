# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AskVAApi::Inquiries::Creator do
  let(:icn) { '123456' }
  let(:service) { instance_double(Crm::Service) }
  let(:creator) { described_class.new(icn:, service:) }
  let(:file_path) { 'modules/ask_va_api/config/locales/get_inquiries_mock_data.json' }
  let(:base64_encoded_file) { Base64.strict_encode64(File.read(file_path)) }
  let(:file) { "data:image/png;base64,#{base64_encoded_file}" }
  let(:inquiry_params) do
    { 'are_you_the_dependent' => 'false',
      'attachment_present' => 'true',
      'branch_of_service' => '722310000',
      'city' => 'Dallas',
      'contact_method' => '722310000',
      'country' => '722310186',
      'daytime_phone' => '(989)898-9898',
      'dependant_city' => nil,
      'dependant_country' => '722310000',
      'dependant_dob' => nil,
      'dependant_email' => nil,
      'dependant_first_name' => nil,
      'dependant_gender' => nil,
      'dependant_last_name' => nil,
      'dependant_middle_name' => nil,
      'dependant_province' => '722310005',
      'dependant_relationship' => '722310006',
      'dependant_ssn' => nil,
      'dependant_state' => nil,
      'dependant_street_address' => nil,
      'dependant_zip_code' => nil,
      'email_address' => 'vets.gov.user+119@gmail.com',
      'email_confirmation' => 'vets.gov.user+119@gmail.com',
      'first_name' => 'Glen',
      'gender' => 'M',
      'inquiry_about' => '722310000',
      'inquiry_category' => '5c524deb-d864-eb11-bb24-000d3a579c45',
      'inquiry_source' => '722310004',
      'inquiry_subtopic' => '932a8586-e764-eb11-bb23-000d3a579c3f',
      'inquiry_summary' => 'string',
      'inquiry_topic' => '932a8586-e764-eb11-bb23-000d3a579c3f',
      'inquiry_type' => '722310001',
      'is_va_employee' => 'true',
      'is_veteran' => 'true',
      'is_veteran_an_employee' => 'true',
      'is_veteran_deceased' => 'false',
      'level_of_authentication' => '722310001',
      'medical_center' => '07a51029-6816-e611-9436-0050568d743d',
      'middle_name' => 'Lee',
      'preferred_name' => nil,
      'pronouns' => 'He/Him',
      'street_address2' => nil,
      'submitter' => '42cc2a0a-2ebf-e711-9495-0050568d63d9',
      'submitter_dependent' => '722310000',
      'submitter_dob' => '1971-12-08',
      'submitter_gender' => 'M',
      'submitter_province' => '722310008',
      'submitter_question' => 'I would like to know more about my claims',
      'submitters_dod_id_edipi_number' => '987654321',
      'submitter_ssn' => '796231077',
      'submitter_state' => 'TX',
      'submitter_state_of_residency' => 'TX',
      'submitter_state_of_school' => 'TX',
      'submitter_state_property' => 'TX',
      'submitter_street_address' => '4343 Rosemeade Pkwy',
      'submitter_vet_center' => '200ESR',
      'submitter_zip_code_of_residency' => '75287-2950',
      'suffix' => '722310001',
      'supervisor_flag' => 'true',
      'va_employee_time_stamp' => nil,
      'veteran_city' => 'Dallas',
      'veteran_claim_number' => nil,
      'veteran_country' => '722310186',
      'veteran_date_of_death' => nil,
      'veteran_dob' => '1971-12-08',
      'veteran_dod_id_edipi_number' => '987654321',
      'veteran_email' => 'vets.gov.user+119@gmail.com',
      'veteran_email_confirmation' => 'vets.gov.user+119@gmail.com',
      'veteran_enrolled' => 'true',
      'veteran_first_name' => 'Glen',
      'veteran_icn' => nil,
      'veteran_last_name' => 'Wells',
      'veteran_middle_name' => 'Lee',
      'veteran_phone' => '(989)898-9898',
      'veteran_prefered_name' => nil,
      'veteran_pronouns' => 'He/Him',
      'veteran_province' => '722310005',
      'veteran_relationship' => '722310003',
      'veteran_service_end_date' => '01/01/2000',
      'veteran_service_number' => nil,
      'veteran_service_start_date' => nil,
      'veteran_ssn' => '123456799',
      'veterans_state' => '80b9d1e0-d488-eb11-b1ac-001dd8309d89',
      'veteran_street_address' => '4343 Rosemeade Pkwy',
      'veteran_suffix' => '722310001',
      'veteran_suite_apt_other' => nil,
      'veteran_zip_code' => '75287-2950',
      'who_was_their_counselor' => nil,
      'your_last_name' => 'Wells',
      'zip_code' => '75287-2950',
      'profile' =>
       { 'first_name' => 'Glen',
         'middle_name' => 'M',
         'last_name' => 'Wells',
         'preferred_name' => nil,
         'suffix' => '722310001',
         'gender' => 'M',
         'pronouns' => 'He/Him',
         'country' => '722310186',
         'street' => '4343 Rosemeade Pkwy',
         'city' => 'Dallas',
         'state' => 'TX',
         'zip_code' => '75287-2950',
         'province' => nil,
         'business_phone' => '(989)898-9898',
         'personal_phone' => '(989)898-9898',
         'personal_email' => 'vets.gov.user+119@gmail.com',
         'business_email' => 'vets.gov.user+119@gmail.com',
         'school_state' => 'TX',
         'school_facility_code' => '1000000898',
         'service_number' => nil,
         'claim_number' => nil,
         'veteran_service_state_date' => nil,
         'date_of_birth' => '1971-12-08',
         'edipi' => nil },
      'school_obj' =>
       { 'city' => 'Dallas',
         'institution_name' => "Kyle's Institution",
         'regional_office' => '669cbc60-b58d-eb11-b1ac-001dd8309d89',
         'school_facility_code' => '1000000898',
         'state_abbreviation' => '80b9d1e0-d488-eb11-b1ac-001dd8309d89' },
      'attachments' =>
       [{ 'file_name' => 'testfile.pdf',
          'file_content' => file }] }
  end
  let(:endpoint) { AskVAApi::Inquiries::Creator::ENDPOINT }
  let(:translator) { instance_double(AskVAApi::Translator) }
  let(:translated_payload) do
    { AreYouTheDependent: 'false',
      AttachmentPresent: 'true',
      BranchOfService: '722310000',
      City: 'Dallas',
      ContactMethod: '722310000',
      Country: '722310186',
      DaytimePhone: '(989)898-9898',
      DependantCity: nil,
      DependantCountry: '722310000',
      DependantDOB: nil,
      DependantEmail: nil,
      DependantFirstName: nil,
      DependantGender: nil,
      DependantLastName: nil,
      DependantMiddleName: nil,
      DependantProvince: '722310005',
      DependantRelationship: 722_310_005,
      DependantSSN: nil,
      DependantState: nil,
      DependantStreetAddress: nil,
      DependantZipCode: nil,
      EmailAddress: 'vets.gov.user+119@gmail.com',
      EmailConfirmation: 'vets.gov.user+119@gmail.com',
      FirstName: 'Glen',
      Gender: 'M',
      InquiryAbout: 722_310_003,
      InquiryCategory: '5c524deb-d864-eb11-bb24-000d3a579c45',
      InquirySource: 722_310_000,
      InquirySubtopic: '932a8586-e764-eb11-bb23-000d3a579c3f',
      InquirySummary: 'string',
      InquiryTopic: '932a8586-e764-eb11-bb23-000d3a579c3f',
      InquiryType: 722_310_001,
      IsVAEmployee: 'true',
      IsVeteran: 'true',
      IsVeteranAnEmployee: 'true',
      IsVeteranDeceased: 'false',
      LevelOfAuthentication: 722_310_001,
      MedicalCenter: '07a51029-6816-e611-9436-0050568d743d',
      MiddleName: 'Lee',
      PreferredName: nil,
      Pronouns: 'He/Him',
      ResponseType: 722_310_000,
      StreetAddress2: nil,
      Submitter: '42cc2a0a-2ebf-e711-9495-0050568d63d9',
      SubmitterDependent: '722310000',
      SubmitterDOB: '1971-12-08',
      SubmitterGender: 'M',
      SubmitterProvince: '722310008',
      SubmitterQuestion: 'I would like to know more about my claims',
      SubmittersDodIdEdipiNumber: '987654321',
      SubmitterSSN: '796231077',
      SubmitterState: 'TX',
      SubmitterStateOfResidency: 'TX',
      SubmitterStateOfSchool: 'TX',
      SubmitterStateProperty: 'TX',
      SubmitterStreetAddress: '4343 Rosemeade Pkwy',
      SubmitterVetCenter: '200ESR',
      SubmitterZipCodeOfResidency: '75287-2950',
      Suffix: 722_310_000,
      SupervisorFlag: 'true',
      VaEmployeeTimeStamp: nil,
      VeteranCity: 'Dallas',
      VeteranClaimNumber: nil,
      VeteranCountry: '722310186',
      VeteranDateOfDeath: nil,
      VeteranDOB: '1971-12-08',
      VeteranDodIdEdipiNumber: '987654321',
      VeteranEmail: 'vets.gov.user+119@gmail.com',
      VeteranEmailConfirmation: 'vets.gov.user+119@gmail.com',
      VeteranEnrolled: 'true',
      VeteranFirstName: 'Glen',
      VeteranICN: nil,
      VeteranLastName: 'Wells',
      VeteranMiddleName: 'Lee',
      VeteranPhone: '(989)898-9898',
      VeteranPreferedName: nil,
      VeteranPronouns: 'He/Him',
      VeteranProvince: '722310005',
      VeteranRelationship: 722_310_019,
      VeteranServiceEndDate: '01/01/2000',
      VeteranServiceNumber: nil,
      VeteranServiceStartDate: nil,
      VeteranSSN: '123456799',
      VeteransState: '80b9d1e0-d488-eb11-b1ac-001dd8309d89',
      VeteranStreetAddress: '4343 Rosemeade Pkwy',
      VeteranSuffix: '722310001',
      VeteranSuiteAptOther: nil,
      VeteranZipCode: '75287-2950',
      WhoWasTheirCounselor: nil,
      YourLastName: 'Wells',
      ZipCode: '75287-2950',
      Profile: { firstName: 'Glen',
                 middleName: 'M',
                 lastName: 'Wells',
                 preferredName: nil,
                 suffix: '722310001',
                 gender: 'M',
                 pronouns: 'He/Him',
                 country: '722310186',
                 street: '4343 Rosemeade Pkwy',
                 city: 'Dallas',
                 state: 'TX',
                 zipCode: '75287-2950',
                 province: nil,
                 businessPhone: '(989)898-9898',
                 personalPhone: '(989)898-9898',
                 personalEmail: 'vets.gov.user+119@gmail.com',
                 businessEmail: 'vets.gov.user+119@gmail.com',
                 schoolState: 'TX',
                 schoolFacilityCode: '1000000898',
                 serviceNumber: nil,
                 claimNumber: nil,
                 veteranServiceStateDate: nil,
                 dateOfBirth: '1971-12-08',
                 edipi: nil },
      SchoolObj: { City: 'Dallas',
                   InstitutionName: "Kyle's Institution",
                   RegionalOffice: '669cbc60-b58d-eb11-b1ac-001dd8309d89',
                   SchoolFacilityCode: '1000000898',
                   StateAbbreviation: '80b9d1e0-d488-eb11-b1ac-001dd8309d89' },
      ListOfAttachments: [{ fileName: 'testfile.pdf',
                            fileContent: 'base64 string' }] }
  end

  before do
    allow_any_instance_of(Crm::CrmToken).to receive(:call).and_return('token')
    allow(AskVAApi::Translator).to receive(:new).with(inquiry_params:).and_return(translator)
    allow(translator).to receive(:call).and_return(translated_payload)
  end

  describe '#call' do
    context 'when the API call is successful' do
      before do
        allow(service).to receive(:call).and_return({
                                                      Data: {
                                                        InquiryNumber: '530d56a8-affd-ee11-a1fe-001dd8094ff1'
                                                      },
                                                      Message: '',
                                                      ExceptionOccurred: false,
                                                      ExceptionMessage: '',
                                                      MessageId: 'b8ebd8e7-3bbf-49c5-aff0-99503e50ee27'
                                                    })
      end

      it 'assigns VeteranICN and posts data to the service' do
        response = creator.call(inquiry_params:)

        expect(service).to have_received(:call) do |params|
          expect(params[:payload][:VeteranICN]).to eq(icn)
        end

        expect(response).to eq({ InquiryNumber: '530d56a8-affd-ee11-a1fe-001dd8094ff1' })
      end
    end

    context 'when the API call fails' do
      let(:body) do
        '{"Data":null,"Message":"Data Validation: missing InquiryCategory"' \
          ',"ExceptionOccurred":true,"ExceptionMessage":"Data Validation: missing' \
          'InquiryCategory","MessageId":"cb0dd954-ef25-4e56-b0d9-41925e5a190c"}'
      end
      let(:failure) { Faraday::Response.new(response_body: body, status: 400) }

      before do
        allow(service).to receive(:call).and_return(failure)
      end

      it 'raise InquiriesCreatorError' do
        expect { creator.call(inquiry_params:) }.to raise_error(ErrorHandler::ServiceError)
      end
    end
  end
end
