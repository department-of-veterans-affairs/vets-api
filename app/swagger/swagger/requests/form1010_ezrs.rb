context 'with a user that can prefill 10-10EZR' do
  let(:form_profile) do
    FormProfiles::VA1010ezr.new(user:, form_id: 'f')
  end

  context 'when the ee service is down' do
    let(:v10_10_ezr_expected) do
      {
        'veteranFullName' => {
          'first' => user.first_name&.capitalize,
          'middle' => user.middle_name&.capitalize,
          'last' => user.last_name&.capitalize,
          'suffix' => user.suffix
        },
        'veteranSocialSecurityNumber' => user.ssn,
        'gender' => user.gender,
        'veteranDateOfBirth' => user.birth_date,
        'homePhone' => us_phone,
        'veteranAddress' => address,
        'email' => user.va_profile_email
      }
    end

    it 'prefills the rest of the data and logs exception to sentry' do
      expect_any_instance_of(FormProfiles::VA1010ezr).to receive(:log_exception_to_sentry).with(
        instance_of(VCR::Errors::UnhandledHTTPRequestError)
      )
      expect_prefilled('10-10EZR')
    end
  end

  context 'with a user with dependents', run_at: 'Tue, 31 Oct 2023 12:04:33 GMT' do
    let(:v10_10_ezr_expected) do
      {
        'veteranFullName' => {
          'first' => user.first_name&.capitalize,
          'middle' => user.middle_name&.capitalize,
          'last' => user.last_name&.capitalize,
          'suffix' => user.suffix
        },
        'veteranSocialSecurityNumber' => user.ssn,
        'gender' => user.gender,
        'veteranDateOfBirth' => user.birth_date,
        'homePhone' => us_phone,
        'veteranAddress' => address,
        'email' => user.va_profile_email,
        'spouseSocialSecurityNumber' => '435345344',
        'spouseDateOfBirth' => '1950-02-17',
        'dateOfMarriage' => '2000-10-15',
        'cohabitedLastYear' => true,
        'maritalStatus' => 'Married',
        'isMedicaidEligible' => false,
        'isEnrolledMedicarePartA' => false,
        'spouseFullName' => {
          'first' => 'VSDV',
          'last' => 'SDVSDV'
        }
      }
    end

    before do
      allow(user).to receive(:icn).and_return('1012829228V424035')
    end

    it 'returns a prefilled 10-10EZR form' do
      VCR.use_cassette(
        'hca/ee/dependents',
        VCR::MATCH_EVERYTHING.merge(erb: true)
      ) do
        expect_prefilled('10-10EZR')
      end
    end
  end

  context 'with a user with insurance data', run_at: 'Tue, 24 Oct 2023 17:27:12 GMT' do
    let(:v10_10_ezr_expected) do
      {
        'veteranFullName' => {
          'first' => user.first_name&.capitalize,
          'middle' => user.middle_name&.capitalize,
          'last' => user.last_name&.capitalize,
          'suffix' => user.suffix
        },
        'veteranSocialSecurityNumber' => user.ssn,
        'gender' => user.gender,
        'veteranDateOfBirth' => user.birth_date,
        'homePhone' => us_phone,
        'veteranAddress' => address,
        'email' => user.va_profile_email,
        'maritalStatus' => 'Married',
        'isMedicaidEligible' => true,
        'isEnrolledMedicarePartA' => true,
        'medicarePartAEffectiveDate' => '1999-10-16',
        'medicareClaimNumber' => '873462432'
      }
    end

    before do
      allow(user).to receive(:icn).and_return('1013032368V065534')
    end

    it 'returns a prefilled 10-10EZR form' do
      VCR.use_cassette(
        'hca/ee/lookup_user_2023',
        VCR::MATCH_EVERYTHING.merge(erb: true)
      ) do
        expect_prefilled('10-10EZR')
      end
    end
  end
end

context 'with a user that can prefill 10-10EZR' do
  let(:form_profile) do
    FormProfiles::VA1010ezr.new(user:, form_id: 'f')
  end

  context 'when the ee service is down' do
    let(:v10_10_ezr_expected) do
      {
        'veteranFullName' => {
          'first' => user.first_name&.capitalize,
          'middle' => user.middle_name&.capitalize,
          'last' => user.last_name&.capitalize,
          'suffix' => user.suffix
        },
        'veteranSocialSecurityNumber' => user.ssn,
        'gender' => user.gender,
        'veteranDateOfBirth' => user.birth_date,
        'homePhone' => us_phone,
        'veteranAddress' => {
          'street' => street_check[:street],
          'street2' => street_check[:street2],
          'city' => user.address[:city],
          'state' => user.address[:state],
          'country' => user.address[:country],
          'postal_code' => user.address[:postal_code][0..4]
        },
        'email' => user.pciu_email
      }
    end

    it 'prefills the rest of the data and logs exception to sentry' do
      expect_any_instance_of(FormProfiles::VA1010ezr).to receive(:log_exception_to_sentry).with(
        instance_of(VCR::Errors::UnhandledHTTPRequestError)
      )
      expect_prefilled('10-10EZR')
    end
  end

  context 'with a user with dependents', run_at: 'Tue, 31 Oct 2023 12:04:33 GMT' do
    let(:v10_10_ezr_expected) do
      {
        'veteranFullName' => {
          'first' => user.first_name&.capitalize,
          'middle' => user.middle_name&.capitalize,
          'last' => user.last_name&.capitalize,
          'suffix' => user.suffix
        },
        'veteranSocialSecurityNumber' => user.ssn,
        'gender' => user.gender,
        'veteranDateOfBirth' => user.birth_date,
        'homePhone' => us_phone,
        'veteranAddress' => {
          'street' => street_check[:street],
          'street2' => street_check[:street2],
          'city' => user.address[:city],
          'state' => user.address[:state],
          'country' => user.address[:country],
          'postal_code' => user.address[:postal_code][0..4]
        },
        'email' => user.pciu_email,
        'spouseSocialSecurityNumber' => '435345344',
        'spouseDateOfBirth' => '1950-02-17',
        'dateOfMarriage' => '2000-10-15',
        'cohabitedLastYear' => true,
        'maritalStatus' => 'Married',
        'isMedicaidEligible' => false,
        'isEnrolledMedicarePartA' => false,
        'spouseFullName' => {
          'first' => 'VSDV',
          'last' => 'SDVSDV'
        }
      }
    end

    before do
      allow(user).to receive(:icn).and_return('1012829228V424035')
    end

    it 'returns a prefilled 10-10EZR form' do
      VCR.use_cassette(
        'hca/ee/dependents',
        VCR::MATCH_EVERYTHING.merge(erb: true)
      ) do
        expect_prefilled('10-10EZR')
      end
    end
  end

  context 'with a user with insurance data', run_at: 'Tue, 24 Oct 2023 17:27:12 GMT' do
    let(:v10_10_ezr_expected) do
      {
        'veteranFullName' => {
          'first' => user.first_name&.capitalize,
          'middle' => user.middle_name&.capitalize,
          'last' => user.last_name&.capitalize,
          'suffix' => user.suffix
        },
        'veteranSocialSecurityNumber' => user.ssn,
        'gender' => user.gender,
        'veteranDateOfBirth' => user.birth_date,
        'homePhone' => us_phone,
        'veteranAddress' => {
          'street' => street_check[:street],
          'street2' => street_check[:street2],
          'city' => user.address[:city],
          'state' => user.address[:state],
          'country' => user.address[:country],
          'postal_code' => user.address[:postal_code][0..4]
        },
        'email' => user.pciu_email,
        'maritalStatus' => 'Married',
        'isMedicaidEligible' => true,
        'isEnrolledMedicarePartA' => true,
        'medicarePartAEffectiveDate' => '1999-10-16',
        'medicareClaimNumber' => '873462432'
      }
    end

    before do
      allow(user).to receive(:icn).and_return('1013032368V065534')
    end

    it 'returns a prefilled 10-10EZR form' do
      VCR.use_cassette(
        'hca/ee/lookup_user_2023',
        VCR::MATCH_EVERYTHING.merge(erb: true)
      ) do
        expect_prefilled('10-10EZR')
      end
    end
  end
end