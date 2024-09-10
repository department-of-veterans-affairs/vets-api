# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'AskVAApi::V0::Inquiries', type: :request do
  let(:inquiry_path) { '/ask_va_api/v0/inquiries' }
  let(:logger) { instance_double(LogService) }
  let(:span) { instance_double(Datadog::Tracing::Span) }
  let(:icn) { I18n.t('ask_va_api.test_users.test_user_229_icn') }
  let(:authorized_user) { build(:user, :accountable_with_sec_id, icn:) }
  let(:mock_inquiries) do
    JSON.parse(File.read('modules/ask_va_api/config/locales/get_inquiries_mock_data.json'))['Data']
  end
  let(:valid_id) { mock_inquiries.first['InquiryNumber'] }
  let(:invalid_id) { 'A-20240423-30709' }
  let(:static_data_mock) { File.read('modules/ask_va_api/config/locales/static_data.json') }
  let(:cache_data) { JSON.parse(static_data_mock, symbolize_names: true) }

  before do
    allow(LogService).to receive(:new).and_return(logger)
    allow(logger).to receive(:call).and_yield(span)
    allow(span).to receive(:set_tag)
    allow(Rails.logger).to receive(:error)
    allow_any_instance_of(Crm::CrmToken).to receive(:call).and_return('token')
    allow_any_instance_of(AskVAApi::RedisClient).to receive(:fetch)
      .with('categories_topics_subtopics')
      .and_return(cache_data)
  end

  shared_examples_for 'common error handling' do |status, action, error_message|
    it 'logs and renders error and sets datadog tags' do
      expect(response).to have_http_status(status)
      expect(JSON.parse(response.body)['error']).to eq(error_message)
      expect(logger).to have_received(:call).with(action)
      expect(span).to have_received(:set_tag).with('error', true)
      expect(span).to have_received(:set_tag).with('error.msg', error_message)
      expect(Rails.logger).to have_received(:error).with("Error during #{action}: #{error_message}")
    end
  end

  describe 'GET #index' do
    context 'when user is signed in' do
      before { sign_in(authorized_user) }

      context 'when everything is okay' do
        let(:json_response) do
          { 'id' => '4',
            'type' => 'inquiry',
            'attributes' =>
             { 'inquiry_number' => 'A-4',
               'attachments' => [{ 'Id' => '4', 'Name' => 'testfile.txt' }],
               'category_name' => 'Benefits issues outside the U.S.',
               'created_on' => '8/5/202 4:51:52 PM',
               'correspondences' => nil,
               'has_been_split' => true,
               'inquiry_topic' => 'All other Questions',
               'level_of_authentication' => 'Personal',
               'last_update' => '3/20/23',
               'queue_id' => '987654',
               'queue_name' => 'Compensation',
               'status' => 'In Progress',
               'submitter_question' => 'What is compensation?',
               'school_facility_code' => '0123',
               'veteran_relationship' => 'self' } }
        end

        before { get inquiry_path, params: { user_mock_data: true, page: 1, per_page: 10 } }

        it { expect(response).to have_http_status(:ok) }
        it { expect(JSON.parse(response.body)['data']).to include(json_response) }
      end

      context 'when an error occurs' do
        context 'when a service error' do
          let(:error_message) do
            'AskVAApi::Inquiries::InquiriesRetrieverError: Data Validation: No Contact found by ICN'
          end

          before do
            allow_any_instance_of(Crm::Service)
              .to receive(:call)
              .and_raise(Crm::ErrorHandler::ServiceError.new(error_message))
            get inquiry_path
          end

          it_behaves_like 'common error handling', :unprocessable_entity, 'service_error',
                          'Crm::ErrorHandler::ServiceError: ' \
                          'AskVAApi::Inquiries::InquiriesRetrieverError: Data Validation: No Contact found by ICN'
        end

        context 'when a standard error' do
          let(:error_message) { 'standard error' }

          before do
            allow_any_instance_of(Crm::Service)
              .to receive(:call)
              .and_raise(StandardError.new(error_message))
            get inquiry_path
          end

          it_behaves_like 'common error handling', :unprocessable_entity, 'service_error',
                          'StandardError: standard error'
        end
      end
    end

    context 'when user is not signed in' do
      before { get inquiry_path }

      it { expect(response).to have_http_status(:unauthorized) }
    end
  end

  describe 'GET #show' do
    let(:expected_response) do
      { 'data' =>
        { 'id' => '1',
          'type' => 'inquiry',
          'attributes' =>
          { 'inquiry_number' => 'A-1',
            'attachments' => [{ 'Id' => '1', 'Name' => 'testfile.txt' }],
            'category_name' => 'Veteran Affairs  - Debt',
            'created_on' => '8/5/202 4:51:52 PM',
            'correspondences' =>
            { 'data' =>
              [{ 'id' => '1',
                 'type' => 'correspondence',
                 'attributes' =>
                 { 'message_type' => '722310001: Response from VA',
                   'created_on' => '1/2/23 4:45:45 PM',
                   'modified_on' => '1/2/23 5:45:45 PM',
                   'status_reason' => 'Completed/Sent',
                   'description' => 'Your claim is still In Progress',
                   'enable_reply' => true,
                   'attachments' => [{ 'Id' => '12', 'Name' => 'correspondence_1_attachment.pdf' }] } }] },
            'has_been_split' => true,
            'inquiry_topic' => 'Status of a pending claim',
            'level_of_authentication' => 'Personal',
            'last_update' => '12/20/23',
            'queue_id' => '987654',
            'queue_name' => 'Debt Management Center',
            'status' => 'Replied',
            'submitter_question' => 'What is my status?',
            'school_facility_code' => '0123',
            'veteran_relationship' => 'self' } } }
    end

    context 'when user is signed in' do
      context 'when mock is given' do
        before do
          sign_in(authorized_user)
          get "#{inquiry_path}/#{valid_id}", params: { user_mock_data: true }
        end

        it { expect(response).to have_http_status(:ok) }
        it { expect(JSON.parse(response.body)).to eq(expected_response) }
      end

      context 'when mock is not given' do
        let(:crm_response) do
          { Data: [{
            InquiryHasBeenSplit: true,
            CategoryId: '5c524deb-d864-eb11-bb24-000d3a579c45',
            CreatedOn: '8/5/2024 4:51:52 PM',
            Id: 'a6c3af1b-ec8c-ee11-8178-001dd804e106',
            InquiryLevelOfAuthentication: 'Personal',
            InquiryNumber: 'A-123456',
            InquiryStatus: 'In Progress',
            InquiryTopic: 'Cemetery Debt',
            LastUpdate: '1/1/1900',
            QueueId: '9876t54',
            QueueName: 'Debt Management Center',
            SchoolFacilityCode: '0123',
            SubmitterQuestion: 'My question is... ',
            VeteranRelationship: 'self',
            AttachmentNames: [
              {
                Id: '012345',
                Name: 'File A.pdf'
              }
            ]
          }] }
        end
        let(:expected_response) do
          { 'data' =>
            { 'id' => 'a6c3af1b-ec8c-ee11-8178-001dd804e106',
              'type' => 'inquiry',
              'attributes' =>
              { 'inquiry_number' => 'A-123456',
                'attachments' => [{ 'Id' => '012345', 'Name' => 'File A.pdf' }],
                'category_name' => 'Veteran Affairs  - Debt',
                'created_on' => '8/5/2024 4:51:52 PM',
                'correspondences' =>
                { 'data' =>
                  [{ 'id' => 'a6c3af1b-ec8c-ee11-8178-001dd804e106',
                     'type' => 'correspondence',
                     'attributes' =>
                     { 'message_type' => nil,
                       'created_on' => '8/5/2024 4:51:52 PM',
                       'modified_on' => nil,
                       'status_reason' => nil,
                       'description' => nil,
                       'enable_reply' => nil,
                       'attachments' => [{ 'Id' => '012345', 'Name' => 'File A.pdf' }] } }] },
                'has_been_split' => true,
                'inquiry_topic' => 'Cemetery Debt',
                'level_of_authentication' => 'Personal',
                'last_update' => '1/1/1900',
                'queue_id' => '9876t54',
                'queue_name' => 'Debt Management Center',
                'status' => 'In Progress',
                'submitter_question' => 'My question is... ',
                'school_facility_code' => '0123',
                'veteran_relationship' => 'self' } } }
        end
        let(:service) { instance_double(Crm::Service) }

        before do
          allow(Crm::Service).to receive(:new).and_return(service)
          allow_any_instance_of(Crm::CrmToken).to receive(:call).and_return('Token')
          allow(service).to receive(:call).and_return(crm_response)
          sign_in(authorized_user)
          get "#{inquiry_path}/#{valid_id}"
        end

        it { expect(response).to have_http_status(:ok) }
        it { expect(JSON.parse(response.body)).to eq(expected_response) }
      end

      context 'when the id is invalid' do
        let(:body) do
          '{"Data":null,"Message":"Data Validation: No Inquiries found by ID A-20240423-30709"' \
            ',"ExceptionOccurred":true,"ExceptionMessage":"Data Validation: No Inquiries found by ' \
            'ID A-20240423-30709","MessageId":"ca5b990a-63fe-407d-a364-46caffce12c1"}'
        end
        let(:failure) { Faraday::Response.new(response_body: body, status: 400) }
        let(:service) { instance_double(Crm::Service) }

        before do
          allow(Crm::Service).to receive(:new).and_return(service)
          allow_any_instance_of(Crm::CrmToken).to receive(:call).and_return('Token')
          allow(service).to receive(:call).and_return(failure)
          sign_in(authorized_user)
          get "#{inquiry_path}/#{invalid_id}"
        end

        it { expect(response).to have_http_status(:unprocessable_entity) }

        it_behaves_like 'common error handling', :unprocessable_entity, 'service_error',
                        'AskVAApi::Inquiries::InquiriesRetrieverError: ' \
                        '{"Data":null,"Message":"Data Validation: No Inquiries found by ID A-20240423-30709"' \
                        ',"ExceptionOccurred":true,"ExceptionMessage":"Data Validation: No Inquiries found by ' \
                        'ID A-20240423-30709","MessageId":"ca5b990a-63fe-407d-a364-46caffce12c1"}'
      end
    end
  end

  describe 'GET #download_attachment' do
    let(:id) { '1' }

    before do
      sign_in(authorized_user)
    end

    context 'when successful' do
      before do
        get '/ask_va_api/v0/download_attachment', params: { id:, mock: true }
      end

      it 'response with 200' do
        expect(response).to have_http_status(:ok)
      end
    end

    context 'when Crm raise an error' do
      let(:body) do
        '{"Data":null,"Message":"Data Validation: Invalid GUID, Parsing Failed",' \
          '"ExceptionOccurred":true,"ExceptionMessage":"Data Validation: Invalid GUID,' \
          ' Parsing Failed","MessageId":"c14c61c4-a3a8-4200-8c86-bdc09c261308"}'
      end
      let(:failure) { Faraday::Response.new(response_body: body, status: 400) }

      before do
        allow_any_instance_of(Crm::CrmToken).to receive(:call).and_return('token')
        allow_any_instance_of(Crm::Service).to receive(:call)
          .with(endpoint: 'attachment', payload: { id: '1' }).and_return(failure)
        get '/ask_va_api/v0/download_attachment', params: { id:, mock: nil }
      end

      it 'raise the error' do
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe 'GET #profile' do
    context 'when a user is signed in' do
      before do
        sign_in(authorized_user)
        get '/ask_va_api/v0/profile', params: { user_mock_data: true }
      end

      it 'response with 200' do
        expect(response).to have_http_status(:ok)
      end
    end

    context 'when the service call fails' do
      subject(:retriever) { described_class.new(icn: '123') }

      let(:body) do
        '{"Data":null,"Message":"Data Validation: No Contact found"' \
          ',"ExceptionOccurred":true,"ExceptionMessage":"Data Validation: No Contact found ' \
          '","MessageId":"ca5b990a-63fe-407d-a364-46caffce12c1"}'
      end
      let(:service) { instance_double(Crm::Service) }
      let(:failure) { Faraday::Response.new(response_body: body, status: 400) }

      before do
        allow(Crm::Service).to receive(:new).and_return(service)
        allow(service).to receive(:call)
        allow_any_instance_of(Crm::CrmToken).to receive(:call).and_return('Token')
        allow(service).to receive(:call).and_return(failure)
        sign_in(authorized_user)
        get '/ask_va_api/v0/profile'
      end

      it 'raise InvalidProfileError' do
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it_behaves_like 'common error handling', :unprocessable_entity, 'service_error',
                      'AskVAApi::Profile::InvalidProfileError: ' \
                      '{"Data":null,"Message":"Data Validation: No Contact found"' \
                      ',"ExceptionOccurred":true,"ExceptionMessage":"Data Validation: No Contact found ' \
                      '","MessageId":"ca5b990a-63fe-407d-a364-46caffce12c1"}'
    end
  end

  describe 'GET #status' do
    context 'When succesful' do
      before do
        allow_any_instance_of(Crm::CrmToken).to receive(:call).and_return('Token')
        allow_any_instance_of(Crm::Service)
          .to receive(:call).and_return({
                                          Data: {
                                            Status: 'Reopened',
                                            InquiryLevelOfAuthentication: 'Personal'
                                          },
                                          Message: nil,
                                          ExceptionOccurred: false,
                                          ExceptionMessage: nil,
                                          MessageId: '26f5be95-87c6-47f0-9722-1abb5f1a59b5'
                                        })
        get "/ask_va_api/v0/inquiries/#{valid_id}/status"
      end

      it 'returns the status for the given inquiry id' do
        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)['data']).to eq({ 'id' => nil,
                                                          'type' => 'inquiry_status',
                                                          'attributes' => { 'status' => 'Reopened' } })
      end
    end

    context 'When not successful' do
      let(:endpoint) { AskVAApi::Inquiries::Status::Retriever::ENDPOINT }
      let(:body) do
        '{"Data":null,"Message":"Data Validation: No Inquiries found",' \
          '"ExceptionOccurred":true,' \
          '"ExceptionMessage":"Data Validation: No Inquiries found",' \
          '"MessageId":"28cda301-5977-4052-a391-9ab36d514919"}'
      end
      let(:failure) { Faraday::Response.new(response_body: body, status: 400) }
      let(:payload) { { InquiryNumber: 'A-1' } }

      before do
        allow_any_instance_of(Crm::CrmToken).to receive(:call).and_return('Token')
        allow_any_instance_of(Crm::Service).to receive(:call)
          .with(endpoint:, payload:).and_return(failure)
        get "/ask_va_api/v0/inquiries/#{valid_id}/status"
      end

      it 'raise StatusRetrieverError' do
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it_behaves_like 'common error handling', :unprocessable_entity, 'service_error',
                      'AskVAApi::Inquiries::Status::StatusRetrieverError: ' \
                      '{"Data":null,"Message":"Data Validation: No Inquiries found",' \
                      '"ExceptionOccurred":true,' \
                      '"ExceptionMessage":"Data Validation: No Inquiries found",' \
                      '"MessageId":"28cda301-5977-4052-a391-9ab36d514919"}'
    end
  end

  describe 'POST #create' do
    let(:payload) do
      {
        inquiry_category: '5c524deb-d864-eb11-bb24-000d3a579c45',
        inquiry_source: 722_310_004,
        inquiry_subtopic: '932a8586-e764-eb11-bb23-000d3a579c3f',
        inquiry_topic: '932a8586-e764-eb11-bb23-000d3a579c3f',
        submitter_question: 'test',
        are_you_the_dependent: true,
        attachment_present: false,
        branch_of_service: 722_310_000,
        city: 'Queens',
        contact_method: 722_310_001,
        country: 722_310_000,
        daytime_phone: '1235559090',
        dependant_city: 'Morrilton',
        dependant_country: 722_310_000,
        dependant_day_time_phone: '1235559090',
        dependant_dob: '01/01/2000',
        dependant_email: 'test@email.com',
        dependant_first_name: 'Peter',
        dependant_gender: 'M',
        dependant_last_name: 'Parker',
        dependant_middle_name: 'B',
        dependant_province: 722_310_008,
        dependant_relationship: 722_310_007,
        dependant_ssn: '123456789',
        dependant_state: '80b9d1e0-d488-eb11-b1ac-001dd8309d89',
        dependant_street_address: 'TEST',
        dependant_zip_code: '72156',
        email_address: 'test@email.com',
        email_confirmation: 'test@email.com',
        first_name: 'Pete',
        gender: 'M',
        inquiry_about: 722_310_003,
        inquiry_summary: 'string',
        inquiry_type: 722_310_001,
        is_va_employee: true,
        is_veteran: true,
        is_veteran_an_employee: true,
        is_veteran_deceased: true,
        level_of_authentication: 722_310_001,
        medical_center: '07a51029-6816-e611-9436-0050568d743d',
        middle_name: 'MiddleName',
        preferred_name: 'Petey',
        pronouns: 'string',
        school_obj: {
          school_facility_code: '1000000898',
          institution_name: "Kyle's Institution",
          city: 'Boston',
          state_abbreviation: '80b9d1e0-d488-eb11-b1ac-001dd8309d89',
          regional_office: '669cbc60-b58d-eb11-b1ac-001dd8309d89'
        },
        street_address2: 'string',
        submitter: '42cc2a0a-2ebf-e711-9495-0050568d63d9',
        submitter_dependent: 722_310_000,
        submitter_dob: '01/01/2000',
        submitter_gender: 'M',
        submitter_province: 722_310_008,
        submitters_dod_id_edipi_number: 'string',
        submitter_ssn: 'string',
        submitter_state: '80b9d1e0-d488-eb11-b1ac-001dd8309d89',
        submitter_state_of_residency: '80b9d1e0-d488-eb11-b1ac-001dd8309d89',
        submitter_state_of_school: '80b9d1e0-d488-eb11-b1ac-001dd8309d89',
        submitter_state_property: '80b9d1e0-d488-eb11-b1ac-001dd8309d89',
        submitter_street_address: 'string',
        submitter_vet_center: 'string',
        submitter_zip_code_of_residency: 'e3df3e75-54a1-eb11-b1ac-001dd804abe6',
        suffix: 722_310_001,
        supervisor_flag: true,
        va_employee_time_stamp: 'string',
        veteran_city: 'string',
        veteran_claim_number: 'string',
        veteran_country: 722_310_186,
        veteran_date_of_death: '01/01/2000',
        veteran_dob: '01/01/2000',
        veteran_dod_id_edipi_number: 'string',
        veteran_email: 'string',
        veteran_email_confirmation: 'string',
        veteran_enrolled: true,
        veteran_first_name: 'string',
        veteran_icn: 'string',
        veteran_last_name: 'string',
        veteran_middle_name: 'string',
        veteran_phone: 'string',
        veteran_prefered_name: 'string',
        veteran_pronouns: 'string',
        veteran_province: 722_310_005,
        veteran_relationship: 722_310_008,
        veteran_service_end_date: '01/01/2000',
        veteran_service_number: 'string',
        veteran_service_start_date: '01/01/1960',
        veteran_ssn: 'string',
        veterans_state: '80b9d1e0-d488-eb11-b1ac-001dd8309d89',
        veteran_street_address: 'string',
        veteran_suffix: 722_310_001,
        veteran_suite_apt_other: 'string',
        veteran_zip_code: 'string',
        who_was_their_counselor: 'string',
        your_last_name: 'string',
        zip_code: 'string'
      }
    end
    let(:converted_payload) do
      { AreYouTheDependent: 'true',
        AttachmentPresent: 'false',
        BranchOfService: '722310000',
        City: 'Queens',
        ContactMethod: '722310001',
        Country: '722310000',
        DaytimePhone: '1235559090',
        DependantCity: 'Morrilton',
        DependantCountry: '722310000',
        DependantDOB: '01/01/2000',
        DependantEmail: 'test@email.com',
        DependantFirstName: 'Peter',
        DependantGender: 'M',
        DependantLastName: 'Parker',
        DependantMiddleName: 'B',
        DependantProvince: '722310008',
        DependantRelationship: '722310007',
        DependantSSN: '123456789',
        DependantState: '80b9d1e0-d488-eb11-b1ac-001dd8309d89',
        DependantStreetAddress: 'TEST',
        DependantZipCode: '72156',
        EmailAddress: 'test@email.com',
        EmailConfirmation: 'test@email.com',
        FirstName: 'Pete',
        Gender: 'M',
        InquiryAbout: '722310003',
        InquiryCategory: '5c524deb-d864-eb11-bb24-000d3a579c45',
        InquirySource: '722310004',
        InquirySubtopic: '932a8586-e764-eb11-bb23-000d3a579c3f',
        InquirySummary: 'string',
        InquiryTopic: '932a8586-e764-eb11-bb23-000d3a579c3f',
        InquiryType: '722310001',
        IsVAEmployee: 'true',
        IsVeteran: 'true',
        IsVeteranAnEmployee: 'true',
        IsVeteranDeceased: 'true',
        LevelOfAuthentication: '722310001',
        MedicalCenter: '07a51029-6816-e611-9436-0050568d743d',
        MiddleName: 'MiddleName',
        PreferredName: 'Petey',
        Pronouns: 'string',
        StreetAddress2: 'string',
        Submitter: '42cc2a0a-2ebf-e711-9495-0050568d63d9',
        SubmitterDependent: '722310000',
        SubmitterDOB: '01/01/2000',
        SubmitterGender: 'M',
        SubmitterProvince: '722310008',
        SubmitterQuestion: 'test',
        SubmittersDodIdEdipiNumber: 'string',
        SubmitterSSN: 'string',
        SubmitterState: '80b9d1e0-d488-eb11-b1ac-001dd8309d89',
        SubmitterStateOfResidency: '80b9d1e0-d488-eb11-b1ac-001dd8309d89',
        SubmitterStateOfSchool: '80b9d1e0-d488-eb11-b1ac-001dd8309d89',
        SubmitterStateProperty: '80b9d1e0-d488-eb11-b1ac-001dd8309d89',
        SubmitterStreetAddress: 'string',
        SubmitterVetCenter: 'string',
        SubmitterZipCodeOfResidency: 'e3df3e75-54a1-eb11-b1ac-001dd804abe6',
        Suffix: '722310001',
        SupervisorFlag: 'true',
        VaEmployeeTimeStamp: 'string',
        VeteranCity: 'string',
        VeteranClaimNumber: 'string',
        VeteranCountry: '722310186',
        VeteranDateOfDeath: '01/01/2000',
        VeteranDOB: '01/01/2000',
        VeteranDodIdEdipiNumber: 'string',
        VeteranEmail: 'string',
        VeteranEmailConfirmation: 'string',
        VeteranEnrolled: 'true',
        VeteranFirstName: 'string',
        VeteranICN: 'string',
        VeteranLastName: 'string',
        VeteranMiddleName: 'string',
        VeteranPhone: 'string',
        VeteranPreferedName: 'string',
        VeteranPronouns: 'string',
        VeteranProvince: '722310005',
        VeteranRelationship: '722310008',
        VeteranServiceEndDate: '01/01/2000',
        VeteranServiceNumber: 'string',
        VeteranServiceStartDate: '01/01/1960',
        VeteranSSN: 'string',
        VeteransState: '80b9d1e0-d488-eb11-b1ac-001dd8309d89',
        VeteranStreetAddress: 'string',
        VeteranSuffix: '722310001',
        VeteranSuiteAptOther: 'string',
        VeteranZipCode: 'string',
        WhoWasTheirCounselor: 'string',
        YourLastName: 'string',
        ZipCode: 'string',
        SchoolObj: { City: 'Boston',
                     InstitutionName: "Kyle's Institution",
                     RegionalOffice: '669cbc60-b58d-eb11-b1ac-001dd8309d89',
                     SchoolFacilityCode: '1000000898',
                     StateAbbreviation: '80b9d1e0-d488-eb11-b1ac-001dd8309d89' } }
    end
    let(:endpoint) { AskVAApi::Inquiries::Creator::ENDPOINT }

    context 'when successful' do
      before do
        allow_any_instance_of(Crm::Service).to receive(:call)
          .with(endpoint:, method: :put,
                payload: converted_payload).and_return({
                                                         Data: {
                                                           Id: '530d56a8-affd-ee11-a1fe-001dd8094ff1'
                                                         },
                                                         Message: '',
                                                         ExceptionOccurred: false,
                                                         ExceptionMessage: '',
                                                         MessageId: 'b8ebd8e7-3bbf-49c5-aff0-99503e50ee27'
                                                       })
        sign_in(authorized_user)
        post '/ask_va_api/v0/inquiries/auth', params: payload
      end

      it { expect(response).to have_http_status(:created) }
    end

    context 'when crm api fail' do
      context 'when the API call fails' do
        let(:payload) { { first_name: 'test' } }
        let(:converted_payload) { { FirstName: 'test' } }
        let(:body) do
          '{"Data":null,"Message":"Data Validation: missing InquiryCategory"' \
            ',"ExceptionOccurred":true,"ExceptionMessage":"Data Validation: missing' \
            'InquiryCategory","MessageId":"cb0dd954-ef25-4e56-b0d9-41925e5a190c"}'
        end
        let(:failure) { Faraday::Response.new(response_body: body, status: 400) }

        before do
          allow_any_instance_of(Crm::Service).to receive(:call)
            .with(endpoint:, method: :put,
                  payload: converted_payload).and_return(failure)
          sign_in(authorized_user)
          post '/ask_va_api/v0/inquiries/auth', params: payload
        end

        it 'raise InquiriesCreatorError' do
          expect(response).to have_http_status(:unprocessable_entity)
        end

        it_behaves_like 'common error handling', :unprocessable_entity, 'service_error',
                        'AskVAApi::Inquiries::InquiriesCreatorError: {"Data":null,"Message":' \
                        '"Data Validation: missing InquiryCategory"' \
                        ',"ExceptionOccurred":true,"ExceptionMessage":"Data Validation: missing' \
                        'InquiryCategory","MessageId":"cb0dd954-ef25-4e56-b0d9-41925e5a190c"}'
      end
    end
  end

  describe 'POST #unauth_create' do
    let(:payload) { { first_name: 'Fake', your_last_name: 'Smith' } }
    let(:converted_payload) { { FirstName: 'Fake', YourLastName: 'Smith' } }
    let(:endpoint) { AskVAApi::Inquiries::Creator::ENDPOINT }

    context 'when successful' do
      before do
        allow_any_instance_of(Crm::Service).to receive(:call)
          .with(endpoint:, method: :put,
                payload: converted_payload).and_return({
                                                         Data: {
                                                           Id: '530d56a8-affd-ee11-a1fe-001dd8094ff1'
                                                         },
                                                         Message: '',
                                                         ExceptionOccurred: false,
                                                         ExceptionMessage: '',
                                                         MessageId: 'b8ebd8e7-3bbf-49c5-aff0-99503e50ee27'
                                                       })
        post inquiry_path, params: payload
      end

      it { expect(response).to have_http_status(:created) }
    end

    context 'when crm api fail' do
      context 'when the API call fails' do
        let(:payload) { { first_name: 'test' } }
        let(:converted_payload) { { FirstName: 'test' } }
        let(:body) do
          '{"Data":null,"Message":"Data Validation: missing InquiryCategory"' \
            ',"ExceptionOccurred":true,"ExceptionMessage":"Data Validation: missing' \
            'InquiryCategory","MessageId":"cb0dd954-ef25-4e56-b0d9-41925e5a190c"}'
        end
        let(:failure) { Faraday::Response.new(response_body: body, status: 400) }

        before do
          allow_any_instance_of(Crm::Service).to receive(:call)
            .with(endpoint:, method: :put,
                  payload: converted_payload).and_return(failure)
          post '/ask_va_api/v0/inquiries', params: payload
        end

        it 'raise InquiriesCreatorError' do
          expect(response).to have_http_status(:unprocessable_entity)
        end

        it_behaves_like 'common error handling', :unprocessable_entity, 'service_error',
                        'AskVAApi::Inquiries::InquiriesCreatorError: ' \
                        '{"Data":null,"Message":"Data Validation: missing InquiryCategory"' \
                        ',"ExceptionOccurred":true,"ExceptionMessage":"Data Validation: missing' \
                        'InquiryCategory","MessageId":"cb0dd954-ef25-4e56-b0d9-41925e5a190c"}'
      end
    end
  end

  describe 'POST #upload_attachment' do
    let(:file_path) { 'modules/ask_va_api/config/locales/get_inquiries_mock_data.json' }
    let(:base64_encoded_file) { Base64.strict_encode64(File.read(file_path)) }
    let(:file) { "data:image/png;base64,#{base64_encoded_file}" }
    let(:inquiry_id) { '1c1f5631-9edf-ee11-904d-001dd8306b36' }
    let(:correspondence_id) { nil }
    let(:params) do
      {
        file_name: 'testfile',
        file_content: file,
        inquiry_id:,
        correspondence_id:
      }
    end

    context 'when successful' do
      let(:crm_response) do
        { Data: {
          Id: '1c1f5631-9edf-ee11-904d-001dd8306b36'
        } }
      end

      before do
        allow_any_instance_of(Crm::Service).to receive(:call)
          .with(endpoint: 'attachment/new', payload: {
                  inquiryId: params[:inquiry_id],
                  fileName: params[:file_name],
                  fileContent: file,
                  correspondenceId: params[:correspondence_id]
                }).and_return(crm_response)

        post '/ask_va_api/v0/upload_attachment', params:
      end

      it 'returns http status :ok' do
        expect(response).to have_http_status(:ok)
      end
    end
  end

  describe 'POST #create_reply' do
    let(:payload) { { 'reply' => 'this is my reply' } }

    context 'when successful' do
      before do
        allow_any_instance_of(Crm::Service).to receive(:call).and_return({ Data: { Id: '123' } })
        sign_in(authorized_user)
        post '/ask_va_api/v0/inquiries/123/reply/new', params: payload
      end

      it 'returns status 200' do
        expect(response).to have_http_status(:ok)
      end
    end

    context 'when crm api fail' do
      context 'when the API call fails' do
        let(:endpoint) { 'inquiries/123/reply/new' }
        let(:body) do
          '{"Data":null,"Message":"Data Validation: Missing Reply"' \
            ',"ExceptionOccurred":true,"ExceptionMessage":"Data Validation: ' \
            'Missing Reply","MessageId":"e2cbe041-df91-41f4-8bd2-8b6d9dbb2e38"}'
        end
        let(:failure) { Faraday::Response.new(response_body: body, status: 400) }

        before do
          sign_in(authorized_user)
          allow_any_instance_of(Crm::Service).to receive(:call)
            .with(endpoint:, method: :put,
                  payload: { Reply: 'this is my reply' }).and_return(failure)
          post '/ask_va_api/v0/inquiries/123/reply/new', params: payload
        end

        it 'raise InquiriesCreatorError' do
          expect(response).to have_http_status(:unprocessable_entity)
        end

        it_behaves_like 'common error handling', :unprocessable_entity, 'service_error',
                        'AskVAApi::Correspondences::CorrespondencesCreatorError: ' \
                        '{"Data":null,"Message":"Data Validation: Missing Reply"' \
                        ',"ExceptionOccurred":true,"ExceptionMessage":"Data Validation: ' \
                        'Missing Reply","MessageId":"e2cbe041-df91-41f4-8bd2-8b6d9dbb2e38"}'
      end
    end
  end
end
