module Legacy
  # Holds the connection to the old app's database for Legacy::Import (a connection needs a named class).
  class Source < ActiveRecord::Base
    self.abstract_class = true
  end
end
