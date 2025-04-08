# frozen_string_literal: true

RSpec.shared_context 'shared data' do
  let(:inquiry_params) do
    {
      inquiry: {
        question: 'fasfdas',
        phone_number: '3039751100',
        email_address: 'test@test.com',
        contact_preference: 'Email',
        preferred_name: 'Submitter',
        your_health_facility: 'vha_554',
        pronouns: { he_him_his: 'true' },
        about_the_veteran: {
          first: 'Joseph',
          last: 'New',
          suffix: 'Sr.',
          social_or_service_num: { ssn: '123456799' },
          date_of_birth: '2000-01-01',
          is_veteran_deceased: 'false'
        },
        their_vre_information: 'false',
        is_military_base: 'false',
        veterans_postal_code: '80122',
        family_members_location_of_residence: 'Alabama',
        about_the_family_member: {
          first: 'James',
          last: 'New',
          suffix: 'Jr.',
          date_of_birth: '2000-01-01',
          social_or_service_num: { ssn: '997654321' }
        },
        more_about_your_relationship_to_veteran: 'CHILD',
        is_question_about_veteran_or_someone_else: 'Veteran',
        relationship_to_veteran: "I'm a family member of a Veteran",
        select_category: 'Health care',
        select_topic: 'Audiology and hearing aids',
        who_is_your_question_about: 'Someone else',
        about_yourself: {
          first: 'Your',
          last: 'Self',
          social_or_service_num: {},
          suffix: 'Jr.'
        },
        on_base_outside_us: 'false',
        address: { military_address: {} },
        state_or_residency: {},
        category_id: '73524deb-d864-eb11-bb24-000d3a579c45',
        topic_id: 'c0da1728-d91f-ed11-b83c-001dd8069009',
        subtopic_id: '',
        updated_in_review: '',
        search_location_input: '',
        get_location_in_progress: 'false',
        current_user_location: '',
        get_location_error: 'false',
        selected_facility: nil,
        review_page_view: { open_chapters: [] },
        files: [
          {
            file_name: 'veteran_photo.JpEg',
            file_content: '/9j/4AAQSkZJRgABAQAAAQABAAD'
          }
        ],
        school_obj: {}
      }
    }
  end
  let(:translated_payload) do
    { AreYouTheDependent: false,
      AttachmentPresent: true,
      CaregiverZipCode: nil,
      ContactMethod: 722_310_000,
      DependentDOB: '2000-01-01',
      DependentFirstName: 'James',
      DependentLastName: 'New',
      DependentMiddleName: nil,
      DependentRelationship: nil,
      DependentSSN: '997654321',
      InquiryAbout: 722_310_001,
      InquiryCategory: '73524deb-d864-eb11-bb24-000d3a579c45',
      InquirySource: '722310000',
      InquirySubtopic: '',
      InquirySummary: nil,
      InquiryTopic: 'c0da1728-d91f-ed11-b83c-001dd8069009',
      IsVeteranDeceased: 'false',
      LevelOfAuthentication: 722_310_001,
      MedicalCenter: '2da51029-6816-e611-9436-0050568d743d',
      SchoolObj: { City: nil,
                   InstitutionName: nil,
                   SchoolFacilityCode: nil,
                   StateAbbreviation: nil,
                   RegionalOffice: nil,
                   Update: nil },
      SubmitterQuestion: 'fasfdas',
      SubmitterStateOfSchool: { Name: nil, StateCode: nil },
      SubmitterStateOfProperty: { Name: nil, StateCode: nil },
      SubmitterStateOfResidency: { Name: 'Alabama', StateCode: 'AL' },
      SubmitterZipCodeOfResidency: nil,
      UntrustedFlag: false,
      VeteranDateOfDeath: nil,
      VeteranRelationship: 722_310_007,
      WhoWasTheirCounselor: nil,
      ListOfAttachments: [
        {
          FileName: 'veteran_photo.jpeg',
          FileContent: '/9j/4AAQSkZJRgABAQAAAQABAAD'
        }
      ],
      SubmitterProfile: { FirstName: 'Your',
                          MiddleName: nil,
                          LastName: 'Self',
                          PreferredName: 'Submitter',
                          Suffix: 722_310_000,
                          Pronouns: 'he/him/his',
                          Country: { Name: nil, CountryCode: nil },
                          Street: nil,
                          City: nil,
                          State: { Name: nil, StateCode: nil },
                          ZipCode: nil,
                          DateOfBirth: nil,
                          BusinessPhone: nil,
                          PersonalPhone: '3039751100',
                          BusinessEmail: nil,
                          PersonalEmail: 'test@test.com',
                          SchoolState: nil,
                          SchoolFacilityCode: nil,
                          SchoolId: nil,
                          BranchOfService: nil,
                          SSN: nil,
                          EDIPI: '123',
                          ICN: '234',
                          ServiceNumber: nil,
                          ClaimNumber: nil,
                          VeteranServiceStateDate: nil,
                          VeteranServiceEndDate: nil },
      VeteranProfile: { FirstName: 'Joseph',
                        MiddleName: nil,
                        LastName: 'New',
                        PreferredName: nil,
                        Suffix: 722_310_001,
                        Country: { Name: nil, CountryCode: nil },
                        Street: nil,
                        City: nil,
                        State: { Name: nil, StateCode: nil },
                        ZipCode: '80122',
                        DateOfBirth: '2000-01-01',
                        BranchOfService: nil,
                        SSN: '123456799',
                        EDIPI: nil,
                        ICN: nil,
                        ServiceNumber: nil } }
  end
  let(:veteran_spouse_edu_vrae_flow) do
    {
      inquiry: { category_id: '75524deb-d864-eb11-bb24-000d3a579c45',
                 contact_preference: 'Email',
                 date_of_death: '1999-02-01',
                 email_address: 'test@test.com',
                 family_members_location_of_residence: 'Alabama',
                 is_question_about_veteran_or_someone_else: 'Someone else',
                 on_base_outside_us: false,
                 phone_number: '3039751100',
                 preferred_name: 'Glenny',
                 question: 'test edu and vrae flow',
                 relationship_to_veteran: "I'm a family member of a Veteran",
                 select_category: 'Education benefits and work study',
                 select_topic: 'Veteran Readiness and Employment (Chapter 31)',
                 subject: 'Test',
                 subtopic_id: '',
                 their_vre_information: true,
                 their_vre_counselor: 'Joe Smith',
                 their_relationship_to_veteran: "They're the Veteran's spouse",
                 topic_id: 'b18831a7-8276-ef11-a671-001dd8097cca',
                 who_is_your_question_about: 'Someone else',
                 pronouns: { they_them_theirs: true },
                 address: { military_address: {} },
                 about_yourself: { first: 'Yourself', last: 'Member', social_or_service_num: {} },
                 about_the_veteran: {
                   date_of_birth: '1950-01-01',
                   first: 'Veteran',
                   last: 'Member',
                   is_veteran_deceased: true,
                   social_or_service_num: { ssn: '997654321' }
                 },
                 about_the_family_member: {
                   first: 'Family',
                   last: 'Member',
                   social_or_service_num: { ssn: '123456799' },
                   date_of_birth: '2000-01-01'
                 },
                 state_or_residency: {},
                 files: [{ file_name: nil, file_content: nil }],
                 school_obj: {} }
    }
  end
  let(:i_am_the_veteran_health_care) do
    {
      inquiry: {
        category_id: '73524deb-d864-eb11-bb24-000d3a579c45',
        email_address: 'test@test.com',
        on_base_outside_us: false,
        phone_number: '3039751100',
        question: 'test',
        relationship_to_veteran: "I'm the Veteran",
        select_category: 'Health care',
        select_topic: 'Audiology and hearing aids',
        subtopic_id: '',
        topic_id: 'c0da1728-d91f-ed11-b83c-001dd8069009',
        who_is_your_question_about: 'Myself',
        your_health_facility: 'vba_349b',
        pronouns: {},
        address: { military_address: {} },
        about_yourself: {
          date_of_birth: '1950-01-01',
          first: 'test',
          last: 'test',
          social_or_service_num: { ssn: '123456799' }
        },
        about_the_veteran: { social_or_service_num: {} },
        about_the_family_member: { social_or_service_num: {} },
        state_or_residency: {},
        files: [{ file_name: nil, file_content: nil }],
        school_obj: {}
      }
    }
  end
  let(:i_am_veteran_spouse_center_for_minority) do
    {
      inquiry: { question: 'Testing with User 160 - second submission',
                 on_base_outside_us: false,
                 country: 'USA',
                 address: {
                   street: '8820 Covey Rise Ct',
                   city: 'Charlotte',
                   state: 'NC',
                   postal_code: '28226',
                   country: 'USA'
                 },
                 phone_number: '9898989898',
                 email_address: 'myemail54800658@unattended.com',
                 contact_preference: 'U.S. mail',
                 pronouns: {},
                 date_of_death: '2024-05-01',
                 about_the_veteran: {
                   first: 'VETFirst',
                   last: 'VETLast',
                   is_veteran_deceased: true,
                   social_or_service_num: {
                     ssn: '796127674'
                   },
                   date_of_birth: '1940-02-01'
                 },
                 more_about_your_relationship_to_veteran: "I'm the Veteran's spouse",
                 relationship_to_veteran: "I'm a family member of a Veteran",
                 about_yourself: {
                   first: 'Leslie',
                   middle: 'M',
                   last: 'Rogers',
                   social_or_service_num: {
                     ssn: '796075869'
                   },
                   date_of_birth: '1978-07-06',
                   social_security_number: '796075869'
                 },
                 about_the_family_member: {
                   social_or_service_num: {}
                 },
                 state_or_residency: {},
                 email: 'myemail54800658@unattended.com',
                 phone: '9898989898',
                 select_category: 'Center for Minority Veterans',
                 allow_attachments: false,
                 select_topic: 'Programs and policies',
                 who_is_your_question_about: 'Myself',
                 category_id: '5a524deb-d864-eb11-bb24-000d3a579c45',
                 topic_id: '852a8586-e764-eb11-bb23-000d3a579c3f',
                 subtopic_id: '',
                 updated_in_review: '',
                 search_location_input: '',
                 get_location_in_progress: false,
                 current_user_location: '',
                 get_location_error: false,
                 selected_facility: nil,
                 files: [
                   {
                     file_name: nil,
                     file_content: nil
                   }
                 ],
                 school_obj: {} }
    }
  end
  let(:i_am_veteran_edu) do
    {
      inquiry: {
        subject: 'edu personl 4',
        question: "I'm the veteran",
        relationship_to_veteran: "I'm the Veteran",
        about_yourself: {
          first: 'Theodore',
          middle: 'Matthew',
          last: 'Roberts',
          social_or_service_num: {
            ssn: '796019724'
          },
          date_of_birth: '1986-02-28',
          preferred_name: 'DEMETER',
          social_security_number: '796019724'
        },
        state_of_the_school: nil,
        phone_number: '2507963268',
        email_address: 'valid@somedomain.com',
        business_phone: '2507963268',
        on_base_outside_us: false,
        address: {
          street: '19 S Fremont Ave',
          street2: 'Apt 23',
          city: 'Alhambra',
          state: 'CA',
          military_address: {},
          postal_code: '91801',
          country: 'USA'
        },
        about_the_veteran: {
          social_or_service_num: {}
        },
        about_the_family_member: {
          social_or_service_num: {}
        },
        state_or_residency: {
          school_state: 'AK'
        },
        email: 'valid@somedomain.com',
        phone: '2507963268',
        category_id: '75524deb-d864-eb11-bb24-000d3a579c45',
        select_category: 'Education benefits and work study',
        allow_attachments: true,
        select_topic: 'Transfer of benefits',
        topic_id: '8085b967-8276-ef11-a671-001dd8097cca',
        select_subtopic: 'Transferring benefits to dependents',
        subtopic_id: 'bba71e82-8276-ef11-a671-001dd8097cca',
        files: [
          {
            file_name: nil,
            file_content: nil
          }
        ],
        school_obj: {}
      }
    }
  end
  let(:healthcare_veteran_child) do
    {
      question: 'Testing',
      phone_number: '3039751100',
      email_address: 'test@test.com',
      about_yourself: {
        first: 'Submitter',
        last: 'SubLast',
        suffix: 'II',
        social_or_service_num: {
          ssn: '997654321'
        },
        date_of_birth: '2000-01-01'
      },
      about_the_veteran: {
        first: 'Veteran',
        last: 'VetLast',
        suffix: 'II',
        is_veteran_deceased: false,
        social_or_service_num: {
          ssn: '123456799'
        },
        date_of_birth: '1950-01-01'
      },
      more_about_your_relationship_to_veteran: "I'm the Veteran's child",
      is_question_about_veteran_or_someone_else: 'Veteran',
      relationship_to_veteran: "I'm a family member of a Veteran",
      on_base_outside_us: false,
      address: {
        military_address: {}
      },
      about_the_family_member: {
        social_or_service_num: {}
      },
      state_or_residency: {},
      category_id: '73524deb-d864-eb11-bb24-000d3a579c45',
      select_category: 'Health care',
      allow_attachments: false,
      contact_preferences: ['Email'],
      category_requires_sign_in: false,
      select_topic: 'Audiology and hearing aids',
      topic_id: 'c0da1728-d91f-ed11-b83c-001dd8069009',
      topic_requires_sign_in: false,
      who_is_your_question_about: 'Someone else',
      your_question_requires_sign_in: false,
      your_health_facility: 'vha_674BY',
      files: [
        {
          file_name: nil,
          file_content: nil
        }
      ],
      school_obj: {},
      controller: 'ask_va_api/v0/inquiries',
      action: 'create',
      inquiry: {
        question: 'Testing',
        phone_number: '3039751100',
        email_address: 'test@test.com',
        about_yourself: {
          first: 'Submitter',
          last: 'SubLast',
          suffix: 'II',
          social_or_service_num: {
            ssn: '997654321'
          },
          date_of_birth: '2000-01-01'
        },
        about_the_veteran: {
          first: 'Veteran',
          last: 'VetLast',
          suffix: 'II',
          is_veteran_deceased: false,
          social_or_service_num: {
            ssn: '123456799'
          },
          date_of_birth: '1950-01-01'
        },
        more_about_your_relationship_to_veteran: "I'm the Veteran's child",
        is_question_about_veteran_or_someone_else: 'Veteran',
        relationship_to_veteran: "I'm a family member of a Veteran",
        on_base_outside_us: false,
        address: {
          military_address: {}
        },
        about_the_family_member: {
          social_or_service_num: {}
        },
        state_or_residency: {},
        category_id: '73524deb-d864-eb11-bb24-000d3a579c45',
        select_category: 'Health care',
        allow_attachments: false,
        contact_preferences: ['Email'],
        category_requires_sign_in: false,
        select_topic: 'Audiology and hearing aids',
        topic_id: 'c0da1728-d91f-ed11-b83c-001dd8069009',
        topic_requires_sign_in: false,
        who_is_your_question_about: 'Someone else',
        your_question_requires_sign_in: false,
        your_health_facility: 'vha_674BY',
        files: [
          {
            file_name: nil,
            file_content: nil
          }
        ],
        school_obj: {}
      }
    }
  end
  let(:edu_address) do
    {
      subject: 'test',
      question: 'testing address',
      on_base_outside_us: false,
      country: 'USA',
      address: {
        street: '9092 Rio Blanco ST',
        city: 'Littleton',
        state: 'CO',
        postal_code: '80125'
      },
      phone_number: '3039751100',
      email_address: 'test@test.com',
      contact_preference: 'U.S. mail',
      about_yourself: {
        first: 'Submitter',
        last: 'SubLast',
        suffix: 'III',
        social_or_service_num: {
          ssn: '997654321'
        },
        date_of_birth: '2000-03-01'
      },
      family_member_postal_code: '80112',
      family_members_location_of_residence: 'California',
      their_vre_information: false,
      about_the_family_member: {
        first: 'Family',
        last: 'FamLast',
        suffix: 'II',
        social_or_service_num: {
          ssn: '123456799'
        },
        date_of_birth: '1950-01-01'
      },
      about_your_relationship_to_family_member: "They're my parent",
      relationship_to_veteran: "I'm the Veteran",
      address_validation: {
        city: 'Littleton',
        province: '',
        street2: ''
      },
      about_the_veteran: {
        social_or_service_num: {}
      },
      state_or_residency: {},
      category_id: '75524deb-d864-eb11-bb24-000d3a579c45',
      select_category: 'Education benefits and work study',
      allow_attachments: true,
      contact_preferences: %w[Email Phone USMail],
      category_requires_sign_in: false,
      select_topic: 'Veteran Readiness and Employment (Chapter 31)',
      topic_id: 'b18831a7-8276-ef11-a671-001dd8097cca',
      topic_requires_sign_in: false,
      who_is_your_question_about: 'Someone else',
      your_question_requires_sign_in: false,
      files: [
        {
          file_name: nil,
          file_content: nil
        }
      ],
      school_obj: {},
      controller: 'ask_va_api/v0/inquiries',
      action: 'create',
      inquiry: {
        subject: 'test',
        question: 'testing address',
        on_base_outside_us: false,
        country: 'USA',
        address: {
          street: '9092 Rio Blanco ST',
          city: 'Littleton',
          state: 'CO',
          postal_code: '80125'
        },
        phone_number: '3039751100',
        email_address: 'test@test.com',
        contact_preference: 'U.S. mail',
        about_yourself: {
          first: 'Submitter',
          last: 'SubLast',
          suffix: 'III',
          social_or_service_num: {
            ssn: '997654321'
          },
          date_of_birth: '2000-03-01'
        },
        family_member_postal_code: '80112',
        family_members_location_of_residence: 'California',
        their_vre_information: false,
        about_the_family_member: {
          first: 'Family',
          last: 'FamLast',
          suffix: 'II',
          social_or_service_num: {
            ssn: '123456799'
          },
          date_of_birth: '1950-01-01'
        },
        about_your_relationship_to_family_member: "They're my parent",
        relationship_to_veteran: "I'm the Veteran",
        address_validation: {
          city: 'Littleton',
          province: '',
          street2: ''
        },
        about_the_veteran: {
          social_or_service_num: {}
        },
        state_or_residency: {},
        category_id: '75524deb-d864-eb11-bb24-000d3a579c45',
        select_category: 'Education benefits and work study',
        allow_attachments: true,
        contact_preferences: %w[Email Phone USMail],
        category_requires_sign_in: false,
        select_topic: 'Veteran Readiness and Employment (Chapter 31)',
        topic_id: 'b18831a7-8276-ef11-a671-001dd8097cca',
        topic_requires_sign_in: false,
        who_is_your_question_about: 'Someone else',
        your_question_requires_sign_in: false,
        files: [
          {
            file_name: nil,
            file_content: nil
          }
        ],
        school_obj: {}
      }
    }
  end
  let(:housing_assistance) do
    {
      question: 'testing state of property',
      phone_number: '3039751100',
      email_address: 'test@test.com',
      contact_preference: 'Email',
      state_of_property: 'Colorado',
      about_yourself: {
        first: 'Veteran',
        last: 'VetLast',
        suffix: 'Sr.',
        social_or_service_num: {
          ssn: '123456799'
        },
        date_of_birth: '1950-01-01'
      },
      relationship_to_veteran: "I'm the Veteran",
      on_base_outside_us: false,
      address: {
        military_address: {}
      },
      about_the_veteran: {
        social_or_service_num: {}
      },
      about_the_family_member: {
        social_or_service_num: {}
      },
      state_or_residency: {},
      category_id: '64524deb-d864-eb11-bb24-000d3a579c45',
      select_category: 'Housing assistance and home loans',
      allow_attachments: false,
      contact_preferences: %w[Email Phone],
      category_requires_sign_in: false,
      select_topic: 'Specially Adapted Housing (SAH) and Special Home Adaptation (SHA) grants',
      topic_id: 'b32a8586-e764-eb11-bb23-000d3a579c3f',
      topic_requires_sign_in: false,
      who_is_your_question_about: 'Myself',
      your_question_requires_sign_in: false,
      files: [
        {
          file_name: nil,
          file_content: nil
        }
      ],
      school_obj: {},
      controller: 'ask_va_api/v0/inquiries',
      action: 'create',
      inquiry: {
        question: 'testing state of property',
        phone_number: '3039751100',
        email_address: 'test@test.com',
        contact_preference: 'Email',
        state_of_property: 'Colorado',
        about_yourself: {
          first: 'Veteran',
          last: 'VetLast',
          suffix: 'Sr.',
          social_or_service_num: {
            ssn: '123456799'
          },
          date_of_birth: '1950-01-01'
        },
        relationship_to_veteran: "I'm the Veteran",
        on_base_outside_us: false,
        address: {
          military_address: {}
        },
        about_the_veteran: {
          social_or_service_num: {}
        },
        about_the_family_member: {
          social_or_service_num: {}
        },
        state_or_residency: {},
        category_id: '64524deb-d864-eb11-bb24-000d3a579c45',
        select_category: 'Housing assistance and home loans',
        allow_attachments: false,
        contact_preferences: %w[Email Phone],
        category_requires_sign_in: false,
        select_topic: 'Specially Adapted Housing (SAH) and Special Home Adaptation (SHA) grants',
        topic_id: 'b32a8586-e764-eb11-bb23-000d3a579c3f',
        topic_requires_sign_in: false,
        who_is_your_question_about: 'Myself',
        your_question_requires_sign_in: false,
        files: [
          {
            file_name: nil,
            file_content: nil
          }
        ],
        school_obj: {}
      }
    }
  end
  let(:net_error) do
    {
      inquiry:
     { subject: 'testing',
       question: 'testing Education and CoE flow',
       relationship_to_veteran: "I'm the Veteran",
       about_yourself: {
         first: 'Ray',
         middle: 'Gerald',
         last: 'Bell',
         social_or_service_num: {
           ssn: '111111111'
         },
         date_of_birth: '1989-11-11'
       },
       state_of_the_school: nil,
       state_or_residency: {
         school_state: '',
         residency_state: 'CO'
       },
       phone_number: '4053232444',
       email_address: 'jacob.uhteg@oddball.io',
       business_phone: '13034476565',
       business_email: 'jacob.uhteg@oddball.io',
       address: {
         'view:military_base_description': {},
         country: 'USA',
         street: '1200 The Strand',
         city: 'Manhattan Beach',
         state: 'CA',
         postal_code: '90266',
         military_address: {
           military_post_office: nil,
           military_state: nil
         }
       },
       about_the_veteran: {
         social_or_service_num: {}
       },
       about_the_family_member: {
         social_or_service_num: {}
       },
       has_prefill_information: true,
       initial_form_data: {
         about_yourself: {
           first: 'Ray',
           middle: 'Gerald',
           last: 'Bell',
           social_or_service_num: {
             ssn: '111111111'
           },
           date_of_birth: '1989-11-11'
         },
         state_or_residency: {},
         phone_number: '4053232444',
         email_address: 'jacob.uhteg@oddball.io',
         business_phone: '13034476565',
         business_email: 'jacob.uhteg@oddball.io',
         address: {
           'view:military_base_description': {},
           country: 'USA',
           street: '1200 The Strand',
           city: 'Manhattan Beach',
           state: 'CA',
           postal_code: '90266'
         },
         about_the_veteran: {
           social_or_service_num: {}
         },
         about_the_family_member: {
           social_or_service_num: {}
         }
       },
       category_id: '75524deb-d864-eb11-bb24-000d3a579c45',
       select_category: 'Education benefits and work study',
       allow_attachments: true,
       contact_preferences: [
         'Email'
       ],
       category_requires_sign_in: false,
       select_topic: 'Certificate of Eligibility (COE) or Statement of Benefits',
       topic_id: '5716ab8e-8276-ef11-a671-001dd8097cca',
       topic_requires_sign_in: false,
       country: 'USA',
       files: [
         {
           FileName: nil,
           FileContent: nil
         }
       ],
       school_obj: {
         state_abbreviation: ''
       } }
    }
  end
  let(:net_error_two) do
    {
      inquiry:
     { subject: 'testing',
       question: 'testing edu flow, selecting residency state, then deselect',
       relationship_to_veteran: "I'm the Veteran",
       about_yourself: {
         first: 'Ray',
         middle: 'Gerald',
         last: 'Bell',
         social_or_service_num: {
           ssn: '111111111'
         },
         date_of_birth: '1989-11-11'
       },
       state_of_the_school: nil,
       state_or_residency: {
         school_state: 'CO',
         residency_state: ''
       },
       phone_number: '4053232444',
       email_address: 'jacob.uhteg@oddball.io',
       business_phone: '13034476565',
       business_email: 'jacob.uhteg@oddball.io',
       address: {
         'view:military_base_description': {},
         country: 'USA',
         street: '1200 The Strand',
         city: 'Manhattan Beach',
         state: 'CA',
         postal_code: '90266',
         military_address: {
           military_post_office: nil,
           military_state: nil
         }
       },
       about_the_veteran: {
         social_or_service_num: {}
       },
       about_the_family_member: {
         social_or_service_num: {}
       },
       has_prefill_information: true,
       initial_form_data: {
         about_yourself: {
           first: 'Ray',
           middle: 'Gerald',
           last: 'Bell',
           social_or_service_num: {
             ssn: '111111111'
           },
           date_of_birth: '1989-11-11'
         },
         state_or_residency: {},
         phone_number: '4053232444',
         email_address: 'jacob.uhteg@oddball.io',
         business_phone: '13034476565',
         business_email: 'jacob.uhteg@oddball.io',
         address: {
           'view:military_base_description': {},
           country: 'USA',
           street: '1200 The Strand',
           city: 'Manhattan Beach',
           state: 'CA',
           postal_code: '90266'
         },
         about_the_veteran: {
           social_or_service_num: {}
         },
         about_the_family_member: {
           social_or_service_num: {}
         }
       },
       category_id: '75524deb-d864-eb11-bb24-000d3a579c45',
       select_category: 'Education benefits and work study',
       allow_attachments: true,
       contact_preferences: [
         'Email'
       ],
       category_requires_sign_in: false,
       select_topic: 'Certificate of Eligibility (COE) or Statement of Benefits',
       topic_id: '5716ab8e-8276-ef11-a671-001dd8097cca',
       topic_requires_sign_in: false,
       country: 'USA',
       files: [
         {
           FileName: nil,
           FileContent: nil
         }
       ],
       school_obj: {
         state_abbreviation: 'CO'
       } }
    }
  end
end
