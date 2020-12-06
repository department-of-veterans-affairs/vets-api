module CovidVaccine
  class RegistrationService

    REQUIRED_QUERY_TRAITS = %w[first_name last_name birth_date ssn gender].  

    def register(form_data)
      # TODO: implement
      # coerce form data
      # attempt attributes_from_mpi
      # if result, merge
      # submit to Vetext registry
      # save and return RegistrationSubmission
    end

    def register(form_data, user)
      # TODO: implement
      # coerce form data
      # verify loa3
      # merge attributes_from_user
      # submit to Vetext registry
      # save and return RegistrationSubmission
    end

    private

    def attributes_from_user(user)
      {
        first_name: user.first_name
        last_name: user.last_name
        birth_date: user.birth_date
        ssn: user.ssn
        birth_date: user.birth_date
        icn: user.icn
      }
    end

    def attributes_from_mpi(form_data)
      return {} unless query_traits_present(form_data)
      ui = OpenStruct.new(first_name: form_data['first_name'], 
                          last_name: form_data['last_name'],
                          birth_date: form_data['birth_date'], 
                          ssn: form_data['ssn'], 
                          gender: form_data['gender'], 
                          valid?: true)  
      response = MPI::Service.new.find_profile(ui)
      if response.status == 'OK'
        return {
          icn: response.profile.icn,
          # TODO: return anything else or is it superfluous?
          # Maybe return MPI values since they are canonical
        }
      end
      # TODO: add statsd metrics around MPI queries for both success and fail cases
    end

    def query_traits_present(form_data)
      (REQUIRED_QUERY_TRAITS & form_data.keys).size == REQUIRED_QUERY_TRAITS.size
    end

  end
end

