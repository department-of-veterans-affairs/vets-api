# frozen_string_literal: true

require 'identity/engine'

module Identity

  # Mixin methods so we can find an MPI profile without initializing all the extras
  def find(uuid)
    mpi_profile = FindMpiProfile.new(attrs).call
    identity = Identity::Identity.new()
    return identity
  end

  # Should we use named arguments here?
  def find_by_profile(first_name: '', last_name: '', birth_date: '', ssn: '', gender: '')
  end

  def create(attrs={})
  end
end
