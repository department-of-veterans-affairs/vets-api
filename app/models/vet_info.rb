# frozen_string_literal: true

class VetInfo
  def initialize(user, bgs_person)
    @user = user
    @bgs_person = bgs_person
  end

  def to_686c_form_hash
    {
      'veteran_information' => {
        'full_name' => {
          'first' => @user.first_name,
          'middle' => @user.middle_name,
          'last' => @user.last_name
        },
        'ssn' => @user.ssn,
        'va_file_number' => @bgs_person[:file_nbr].to_s,
        'birth_date' => @user.birth_date
      }
    }
  end
end
