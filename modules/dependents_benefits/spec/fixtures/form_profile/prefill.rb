# frozen_string_literal: true

module FormPrefillSpecData
  def self.v686_c_674_v2_expected(user, us_phone)
    {
      'veteranContactInformation' => veteran_contact_information(user, us_phone),
      'nonPrefill' => non_prefill_data,
      'veteranInformation' => veteran_information(user)
    }
  end

  def self.veteran_contact_information(user, us_phone)
    {
      'veteranAddress' => {
        'street' => '140 Rock Creek Rd',
        'country' => 'USA',
        'city' => 'Washington',
        'state' => 'DC',
        'postalCode' => '20011'
      },
      'phoneNumber' => us_phone,
      'emailAddress' => user.va_profile_email
    }
  end

  def self.non_prefill_data
    {
      'veteranSsnLastFour' => '1863',
      'veteranVaFileNumberLastFour' => '1863',
      'isInReceiptOfPension' => -1,
      'netWorthLimit' => 163_699
    }
  end

  def self.veteran_information(user)
    {
      'fullName' => {
        'first' => user.first_name.capitalize,
        'last' => user.last_name.capitalize
      },
      'ssn' => '796111863',
      'birthDate' => '1809-02-12'
    }
  end
end
