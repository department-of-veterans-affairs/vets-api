# frozen_string_literal: true
module MVI
  class MockService
    def self.mocked_responses
      @responses ||= YAML.load_file('config/mvi_schema/mock_mvi_responses.yml')
    end

    def self.find_candidate(message)
      response = mocked_responses.dig('find_candidate', message.ssn)
      if response
        response
      else
        {
          birth_date: '18090212',
          edipi: '1234^NI^200DOD^USDOD^A',
          family_name: 'Lincoln',
          gender: 'M',
          given_names: ['Abraham'],
          icn: '1000123456V123456^NI^200M^USVHA^P',
          mhv_id: '123456^PI^200MHV^USVHA^A',
          vba_corp_id: '12345678^PI^200CORP^USVBA^A',
          ssn: '272112222',
          status: 'deceased'
        }
      end
    end
  end
end
