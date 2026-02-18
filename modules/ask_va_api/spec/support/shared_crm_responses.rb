# frozen_string_literal: true

RSpec.shared_context 'shared crm responses' do
  let(:crm_success_response) do
    {
      Data: {
        InquiryNumber: '530d56a8-affd-ee11-a1fe-001dd8094ff1',
        ListOfAttachments: [
          {
            FileId: 'string',
            FileName: 'string',
            ErrorMessage: 'string'
          }
        ]
      },
      Message: 'string',
      ExceptionOccurred: false,
      ExceptionMessage: 'string',
      StatusCode: 0,
      AssociatedRecordId: 'string',
      IntegrationResultId: '00000000-0000-0000-0000-000000000000',
      MessageId: '00000000-0000-0000-0000-000000000000'
    }
  end
end
