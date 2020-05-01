class Lighthouse::Facilities::FacilitySerializer < ActiveModel::Serializer
  type 'va_facilities'

  def access
    if object.access['health']
      health = object.access['health'].each_with_object({}) do |key_value, hash|
        service = key_value['service'].downcase
        case service
        when /primarycare/
          hash['primary_care'] = key_value.slice('new','established')      
        else
          hash[service] = key_value.slice('new','established')              
        end
      end
      health['effective_date'] = object.access['effective_date']
      {
        'health': health
      }
    else
      object.access
    end
  end

  def feedback
    if object.feedback['health']
      {
        'health': object.feedback['health'].merge(object.feedback.slice('effective_date'))
      }
    else
      object.feedback
    end
  end

  def services
    if object.services['health']
      {
        'health': object.services['health'].collect {|x| {'sl1' => [x], 'sl2' => []} },
        'last_updated': object.services['last_updated']
      }
    else
      object.services
    end
  end

  attributes  :access,
              :address,
              :classification,
              :facility_type,
              :feedback,
              :hours,
              :lat,
              :long,
              :name,
              :operating_status,
              :phone,
              :services,
              :unique_id,
              :visn,
              :website
end
