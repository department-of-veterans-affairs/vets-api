# frozen_string_literal: true

# rubocop:disable Metrics/ModuleLength
module AccreditedRepresentativePortal
  module Seed
    module Records
      ATTORNEYS = [
        {
          first_name: 'Robert',
          last_name: 'Johnson',
          id: '1bb91d6b-4b0e-49bc-a515-762efaa06017',
          registration_number: '30000',
          poa_code: 'XZY'
        },
        {
          first_name: 'Roberta',
          last_name: 'Johnson',
          id: '1454d96d-9f23-41ae-a841-172f53bb0eaa',
          registration_number: '30001',
          poa_code: 'WQ1'
        },
        {
          first_name: 'Ross',
          last_name: 'Carroll',
          id: '4fa6e645-797d-4d33-9310-9af4631db709',
          registration_number: '30002',
          poa_code: 'J90'
        },
        {
          first_name: 'Gennie',
          last_name: 'Lind',
          id: '67dbeb0b-1412-40e0-9c04-7a1e6221039c',
          registration_number: '30003',
          poa_code: 'O05'
        },
        {
          first_name: 'Bob',
          last_name: 'Law',
          id: 'c72ca933-312e-4149-a455-b47771b6da70',
          registration_number: '30004',
          poa_code: 'XFK'
        }
      ].freeze

      CLAIMS_AGENTS = [
        {
          first_name: 'Bob',
          last_name: 'Agent',
          id: '24769804-018e-4460-a5bb-1124833773cc',
          registration_number: '20000',
          poa_code: 'TVB'
        },
        {
          first_name: 'Desmond',
          last_name: 'McCullough',
          id: '1ddee71a-bfa6-425e-80e0-053a50e8b5be',
          registration_number: '20001',
          poa_code: 'XRO'
        },
        {
          first_name: 'Khalilah',
          last_name: 'Swift',
          id: 'c66de93d-5531-4be6-8ce2-7fdf537be79c',
          registration_number: '20002',
          poa_code: '4HJ'
        },
        {
          first_name: 'Ryan',
          last_name: 'Swift',
          id: '7dcbefbe-4f6a-4c97-9bf1-166e1436a646',
          registration_number: '20003',
          poa_code: 'EUM'
        },
        {
          first_name: 'Alanna',
          last_name: 'Smith',
          id: '69e523d1-bdb0-43da-8ddf-b211ac404213',
          registration_number: '20004',
          poa_code: 'UYX'
        }
      ].freeze

      ORGANIZATIONS = [
        {
          name: 'Trustworthy Organization',
          poa: 'YHZ',
          can_accept_digital_poa_requests: true
        },
        {
          name: 'Good Representatives R Us',
          poa: 'SVS',
          can_accept_digital_poa_requests: true
        },
        {
          name: 'We Help Vets',
          poa: 'FIX',
          can_accept_digital_poa_requests: true
        },
        {
          name: 'The Swift Reps',
          poa: 'MIM',
          can_accept_digital_poa_requests: true
        },
        {
          name: 'Department of Veterans Fake Data',
          poa: 'GWI',
          can_accept_digital_poa_requests: true
        }
      ].freeze

      REPRESENTATIVES = [
        {
          first_name: 'Bob',
          last_name: 'Representative',
          representative_id: '10000',
          user_types: ['veteran_service_officer'],
          poa_codes: %w[YHZ SVS],
          email: 'vets.gov.user+0@gmail.com'
        },
        {
          first_name: 'Robert',
          last_name: 'Lowe',
          representative_id: '10001',
          user_types: ['veteran_service_officer'],
          poa_codes: %w[YHZ],
          email: 'vets.gov.user+1@gmail.com'
        },
        {
          first_name: 'Suzie',
          last_name: 'Lowe',
          representative_id: '10002',
          user_types: ['veteran_service_officer'],
          poa_codes: %w[FIX],
          email: 'vets.gov.user+2@gmail.com'
        },
        {
          first_name: 'Jewell',
          last_name: 'Armstrong',
          representative_id: '10003',
          user_types: ['veteran_service_officer'],
          poa_codes: %w[YHZ],
          email: 'vets.gov.user+4@gmail.com'
        },
        {
          first_name: 'Odis',
          last_name: 'Cruickshank',
          representative_id: '10004',
          user_types: ['veteran_service_officer'],
          poa_codes: %w[YHZ SVS FIX],
          email: 'vets.gov.user+5@gmail.com'
        },
        {
          first_name: 'Catheryn',
          last_name: 'Baumbach',
          representative_id: '10005',
          user_types: ['veteran_service_officer'],
          poa_codes: %w[MIM],
          email: 'vets.gov.user+6@gmail.com'
        },
        {
          first_name: 'Erica',
          last_name: 'Representative',
          representative_id: '10006',
          user_types: ['veteran_service_officer'],
          poa_codes: %w[GWI],
          email: 'vets.gov.user+7@gmail.com'
        }
      ].freeze

      USER_ACCOUNT_ACCREDITED_INDIVIDUALS = [
        {
          accredited_individual_registration_number: '10000',
          user_account_email: 'vets.gov.user+0@gmail.com',
          user_account_icn: '1012667122V019349'
        },
        {
          accredited_individual_registration_number: '10001',
          user_account_email: 'vets.gov.user+1@gmail.com',
          user_account_icn: '1012666182V203559'
        },
        {
          accredited_individual_registration_number: '10002',
          user_account_email: 'vets.gov.user+2@gmail.com',
          user_account_icn: '1012829932V238054'
        },
        {
          accredited_individual_registration_number: '10003',
          user_account_email: 'vets.gov.user+4@gmail.com',
          user_account_icn: '1012659372V317896'
        },
        {
          accredited_individual_registration_number: '10004',
          user_account_email: 'vets.gov.user+5@gmail.com',
          user_account_icn: '1012667179V787205'
        },
        {
          accredited_individual_registration_number: '10005',
          user_account_email: 'vets.gov.user+6@gmail.com',
          user_account_icn: '1012830899V368969'
        },
        {
          accredited_individual_registration_number: '10006',
          user_account_email: 'vets.gov.user+7@gmail.com',
          user_account_icn: '1012643432V477452'
        }
      ].freeze

      CLAIMANTS = [
        {
          id: '7de8ce1e-af1c-4c5d-8caf-4002593dac69'
        },
        {
          id: '3e6f543c-1d24-456e-be14-49e0a0d6eeb1'
        },
        {
          id: '1e6f8e10-3515-498c-b241-00f110ead8e3'
        },
        {
          id: 'fe09af3c-d408-40b2-88e4-b3d78d05a88b'
        },
        {
          id: '8da29bdb-29e3-4b8a-a462-e640d34fdc76'
        },
        {
          id: 'dfe94d0f-4c19-4105-9bf3-eec850b651ac'
        },
        {
          id: '6f1c7f54-46ce-4336-9c4e-103263457cf5'
        },
        {
          id: '77d8f6f9-326d-4304-a61c-f74f68f2d533'
        },
        {
          id: '04f6698b-68c8-40ff-ab82-07899e09eaa8'
        },
        {
          id: '7f26a96a-713c-4780-befe-339b30c98ba9'
        },
        {
          id: '9c86e2f5-a4de-4b91-8822-66ccf560db7b'
        },
        {
          id: '3a764877-02b3-4b8d-b5e7-66204ef67cc3'
        },
        {
          id: 'ca2ec8b1-0733-42eb-9e10-6a5ff2c077e2'
        },
        {
          id: '09d1b85a-8e1b-48b3-b16c-b6b6d1fc8521'
        },
        {
          id: '6febeedd-a134-4317-85d1-3bad378de80e'
        },
        {
          id: '1b879de8-2e8e-4a3f-8f7a-72edcb97ce30'
        },
        {
          id: 'a763d926-33d0-47ad-87d2-cfad63b74132'
        },
        {
          id: '9529f8f9-9d28-4a8e-bef6-d9b47d6adf08'
        },
        {
          id: '7c1236f0-ba8c-4d0c-be76-7dab86150757'
        },
        {
          id: 'e7930f8c-23be-4b97-b4b1-4c006f034a9c'
        },
        {
          id: '40407704-aee4-4c66-998f-1ab9f8d2aa3f'
        },
        {
          id: 'eda90664-4002-44b0-9028-e99156a0f2f1'
        },
        {
          id: 'c93694ce-d64d-4eab-b0a9-4e8da9d6cb0e'
        },
        {
          id: '8bea4d28-da9f-43eb-836f-6d24b4bb5061'
        },
        {
          id: 'ce02c3d8-412f-43af-9711-05771224f09d'
        },
        {
          id: '40ff03e4-19b6-4f70-bdb7-8d6ebe14b11b'
        },
        {
          id: '427f8301-3c37-4311-a318-b71be231de38'
        },
        {
          id: '9c1eef4b-6f43-42c6-8361-9d197ece3d37'
        },
        {
          id: 'dbce479d-88cd-4467-a771-4fab184425f3'
        },
        {
          id: '0ec8246c-259e-41d5-a6fc-d4e12a7f3bad'
        },
        {
          id: '4cdad2aa-87b9-4879-96fe-3effd6a13d83'
        },
        {
          id: 'e61c1158-7d2b-43f3-8a9f-046ffdf1df37'
        },
        {
          id: '80a37238-7f0d-426f-ba14-e76e089fd24b'
        },
        {
          id: 'fcfd3511-2427-4ebd-bc73-8f88e12e6339'
        },
        {
          id: '8c517f83-8cc1-456e-85c0-bfbeb0f11c65'
        },
        {
          id: 'bf7a3db5-e103-4e87-b009-ca7762169ec8'
        },
        {
          id: 'a88f2205-949f-40c4-a925-76a053ddf1b8'
        }
      ].freeze

      POA_REQUEST_IDS = %w[
        345dd27a-db3f-4e8f-8588-e0d589026e44 0b255a94-b9e0-45c8-b313-3c1179178b4f 521ea854-2dee-4b52-b681-401c6c8542f5
        6cb8c41a-7ede-4124-91e3-aeb31932207a 53a1c8f1-0ac2-442b-b6df-768a5324fd78 0657aca0-a8d2-4d09-bf60-114fe0fe468d
        9d9f3880-5ee4-4617-a044-3b1bce8dfb83 a31040b6-0099-492a-822f-d56e0c0f4762 f09dd1b1-a4ef-42a4-82da-055f36ffb410
        3f087751-8938-4215-b8dc-ab67cf729ad1 b9bebdd0-2723-49ad-b809-60ae19264d14 28e253a5-9355-4e05-9a84-c8c37c9cf78d
        1c3d503b-9f18-4eba-828f-dcba2a1d2047 c4e49da5-20bc-4ed3-80fa-e3f2540e1c8e 83326cd5-c349-4939-a4da-ef58f5d8932f
        f854d559-325c-4134-8faa-505c0a234b85 62dff33f-239e-4f75-b895-6b3540306cfb 824c5ddc-be9a-4fdb-9bf9-b0a2fc07aa11
        87c21b4f-1354-4357-bef9-2878ebb9891e c15725e4-dad7-4f31-86b2-59d86a789fbd 6bbce2ba-11db-4896-a4a2-d73284281758
        15c5cdb4-1689-4def-b7f6-0f7134a081b2 7942b09f-b05a-4a43-81d6-11d32a40538b 257656df-41d3-4077-a73e-ada9b5d34b3f
        e31ade63-11ae-4fde-ba97-7db1c94642fc 4a7024c3-71e6-4fc3-8346-e44bb6dcd57b 1af6f9fe-0650-41bc-a068-2d35e201b414
        b8aaabfe-4594-4944-92b2-2bb9d60f5296 cad1914b-9069-4765-bf19-2e75505ed566 2cff8566-e385-49ac-a031-a08da90bd6ff
        890e1aa6-22dd-4742-879b-a5b421fc3323 67e0feca-4029-448f-b2c3-4fd48a548434 9a0ab6dc-4941-41c5-b3d4-a145cef73656
        a03b20ce-12bd-47af-bd31-a39e5a00cf48 968db5ff-78c5-4ac0-820c-53df32ef399f 7169b6ca-fc68-4b29-9520-d6ce3196a094
        4dd04d51-1ba3-4e03-b60b-590c80b5b1c9 6d4fcfb0-84d6-4d71-b2d4-9507e87c81f0 ad59327d-0976-41b7-8d94-b4becdc5d4bf
        4b48bfc3-2ba7-427d-ac14-70da34bf44fd 4b83510c-06a9-4149-8440-e00c532c5b7a bb2631d2-56c2-4f7d-a8a9-851c020193bd
        40c9ffbc-ae32-49c9-ab11-ff9c49105d5b b3d8beb5-af82-4819-a6af-34d9497a52e4 6c322870-b994-4d0f-aaa0-3e1212af0b42
        13e27d16-dbc2-4625-8514-f40a9fe8caaf 38c24e31-2df2-4a5d-bdfe-ac009432f6c3 43f64e87-f58d-402d-99b4-e71284cf7c81
        fbe2ab6a-bf82-4227-9da8-9e59a8a1c757 85071f62-af98-4843-a360-122c172c8974 c83f382f-b026-4819-8d51-a4230cab11d9
        7c979ac1-d0c7-4de8-9483-a66ac88611b0 8e516a07-10bd-4150-8527-c5f194595b92 d5e1766d-8112-47e1-86e9-5252bb42cb1d
        aa8badb2-487d-4c0b-bb61-0a7f682cd09c 883d4d0e-3740-4762-9d31-c3e712974366 b944a0eb-5a90-4562-afa5-60ca38b73079
        69b800fe-2472-40be-af7f-2af57e39ebdd 65c75f04-83ea-41b2-9777-0955acbcab83 c9ade6fa-9364-4df4-a72b-6e950a94c60c
        7f83f738-fbdf-4ba2-b538-17986557995a 8d8805e3-4fc5-4e18-b092-7b81b528e57c 3ec95049-0afb-427f-b26c-3b8212b8979d
        7c9253ec-b598-4c0c-9da1-fd25e8d6c6e3 72b56a69-7037-4db9-8596-d2153187b81e 651750f4-45bd-4b86-9db5-8b046ad061dd
        4fd9a335-e257-4d3b-98ab-2f0aaa26b54f c4c640f8-b41a-4900-bd12-3fbd3eadf036 7cdbf77f-1d1d-4e18-8586-30788e451faf
        69e6138c-56cc-4f9f-95fa-1b40271e5a0a fe90f71e-0786-49aa-b784-a0153ac90cd0 040aaf1a-7f37-413a-874c-a7dedacea424
        0ab6a1b6-1ac2-4aec-acd7-c007ccd59305 b7e2ea23-9744-4cdb-8fb3-2701afd36cee 7da21967-9145-420c-af6f-6b56406d66de
        8971e86f-efe9-41a1-b5ad-36cc20e8d372 96312b2f-c699-4960-ac25-68ca3f952386 c27d1eb7-781e-4c18-9ffb-0797401dc95e
        14ea6796-9fbe-4456-a96d-2919bac8141b 4b42c686-e997-4c3b-8cd9-0bfe45bae839 ecb0befa-0a45-4d77-a702-bf4b983f8adf
        54973318-d456-49a4-bd7d-8b99ea5f9d29 f3d93fb3-3683-4874-a9f5-727d5123b72b a56a3070-c272-46f6-8887-8bc948180acc
        0f5dab09-4025-4e4c-bc3c-46b9097615ad 536ada6c-a158-40a0-bf8d-a580b4d9c2cd f751ccd3-5ef5-4fd6-8020-ab1160addc3c
        c7397103-59e4-4757-bca0-8af18594d490 f41edbbd-cf43-4984-978f-f2f5d68529c6 3e2c1bac-c548-4453-894c-cf84cfd9986d
        f596d10b-4e29-4a93-85c0-280811b24dd3 beb394d6-006a-4f2a-918c-6d35355f3d41 e2a0785d-c92e-4442-9668-4097a1362bfb
        bf3c11a2-ba34-41f0-b9d6-b73bda4b1438 d52be790-a17a-4bf9-b8fe-30dca9078112 6b5ef4bc-d475-4d6f-ad2d-f5e265a613fe
        cf234722-6e63-4b5e-a648-2026328de0e4 520fcf79-68b1-498d-b502-c5eccd51a15f ba85f4d1-97fd-4c35-a051-cdeb5bd8df3c
        bdca8125-98cd-4b37-a395-ff1f1eadc9b1 527cb99e-cab4-42d3-8d61-4775f9210a86 436a3ee4-43f8-4519-9b24-f0d9bf0c3d8f
        46b53341-110b-454d-bae8-6d96619e9db9 86c04682-a297-4998-b3ed-2c7d86f38e6a a6eadef1-c0a8-4ffe-8006-ea361bb98489
        a7f5f822-81f4-47ea-ba0d-fb7f05d498f8 0c1ffc2f-1521-4b27-9b68-9e5deff9e55f 86699b5b-3242-4971-94d5-3ad122519a78
        ec149889-bbb6-4b38-8e43-dd47487e5eea af2caad9-0754-4378-94c4-f9ab8808a4ec 3e179f6b-178f-4a9a-801c-977c5b334613
        cdcfc0e0-4604-4c2a-85e8-03d08682f5f2 760b91ff-4ab1-4f89-8834-37970bb95d59 9e1519ce-a9ad-4d26-b64b-aec72efaec5e
        6f62ad7a-3f48-4ae0-8ea5-f0ac1083f27c 4694687d-0575-4f7a-80ca-3f4a839a759f 44dc0132-fcaf-4179-8174-c1c62ddbde80
        4eb1bc32-6ee3-4a4d-b8bc-913cf8afb76f 672dfe26-3613-4edd-b04a-d0c81451aba3 9e09d344-90b1-42a8-b408-cedb60d95972
        e48a0c80-f590-4e7d-b0dc-d02294795078 df5a2531-d224-4769-b795-adf473e6bb5d 5807129d-4673-4ef8-bf3f-1197c1453cad
        9d40a03c-e69d-4369-8e93-540ee547bf88 784ac270-57b7-48f8-8586-0375cc10623a 9c04de1a-e04e-443c-b3f8-6f6f1d424d25
        4e33b213-4dd6-43b0-9f19-9ea6f7e59878 2eba194b-a6ac-4685-b5cf-b95bd8f4742f da89f76a-6125-42c4-8b9c-12432f0f85d6
        c8bb87fe-5428-4fce-bee8-f1de27131bbd cf5803f1-3053-4786-8fef-506c2cf3ebf2 75866470-40e4-43ec-9262-295a29c62422
        7ed49b6e-4053-465c-90a2-474983732733 7eec9529-1f6f-4645-abd2-f7d5d6ed7476 8a161592-41e5-4021-8e6d-0ba9e6142b6f
        1df3aeaf-1c76-49c0-9195-d39ba64508e6 de60ba8d-a7d2-4cea-8943-3409221f4bb7 716f33c2-6ce4-46ba-8868-f9b33a444b9a
        d18d8d59-790b-4c69-aa8e-077fbb9d1d2c f846d86a-d265-4871-affb-4df29d0b7c9b 793b2a7e-fd37-4279-a5c1-c026d605c8b7
        9f76a044-a056-4e98-b598-fc4938858bff 6ae79b92-e404-47c2-a4d1-649d235904f9 460d70e1-abf1-4ec1-a543-ef43dc3336c2
        42c19538-b515-4d7c-a57e-68cc70534388 e6e91b44-258c-4ad6-abbe-c1d5cf4ab0d0 c08bd995-b2ff-4ace-bbff-07d0355cae69
        c2ec863a-8015-4d71-9706-66a1c02d1637 8ad83b72-e3fe-4167-a05b-5bb32ae8ccbd 91069241-7dc5-49cd-aebc-7d5917e43e76
      ].to_enum
    end
  end
end
# rubocop:enable Metrics/ModuleLength
