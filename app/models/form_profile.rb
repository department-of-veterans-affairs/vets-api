# frozen_string_literal: true
#
# A long living cache of a user's form profile for pre-populating form fields.
# When a form is saved its data is normalized and saved here. This is more of a
# hybrid document cache for speed, rather than as a canonical VA record, so the
# data is fairly flat (first normal form).
#
class FormProfile < ActiveRecord::Base
  attr_encrypted :form_profile_data, key: ENV['DB_ENCRYPTION_KEY']

  # Collects data the VA has on hand for a user. The data may come from many databases/services.
  # In case of collisions, preference is given in this order:
  # * The form profile cache (the record for this class)
  # * ID.me
  # * MVI
  # * TODO(AJD): MIS (military history)
  #
  def query(user, form_id)
    # load form json schema, handle errors
    # map VA data (mvi) based on form's metadata
    form_profile = FormProfile.where(user_uuid: user_uuid).first_or_initialize do |fp|
      fp.form_profile_data = va_profile_from_user(user)
    end
    form_schema = VetsJsonSchema.const_get(form_id.snakecase.upcase)
    form_profile
  end

  # Updates the form profile cache with a form's data. Splits the data into the categories
  # that are shared across forms at the VA:
  # * veteranInformation
  # ..* fullName
  # ....* first
  # ....* middle
  # ....* last
  # ....* suffix
  # ..*
  # * contactInformation
  # ..* address
  # ....* street
  # ....* street2
  # ....* city
  # ....* country
  # ....* state
  # ....* postalCode
  # ..* homePhone
  # ..* mobilePhone
  #
  def update_profile(user_uuid, form_id, form_data)

  end

  private

  def va_profile_from_user(user)
    profile = {
      veteran_information: {
        full_name: {
          first: user.first_name&.capitalize,
          middle: user.middle_name&.capitalize,
          last: user.last_name&.capitalize,
          suffix: user.va_profile[:suffix]
        }
      },
      contact_information: {
        address: {
          street: user.va_profile[:address][:street_address_line],
          street2: nil,
          city: user.va_profile[:address][:city],
          state: user.va_profile[:address][:state],
          postal_code: user.va_profile[:address][:postal_code],
          country: user.va_profile[:address][:country]
        },
        home_phone: user.va_profile[:home_phone],
        mobile_phone: nil
      }
    }
    FormProfile.new(user_uuid: user.uuid, form_profile_data: profile.to_json)
  end

  def to_h
    {
      funk: 'nuts'
    }
  end
end
