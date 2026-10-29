module OneTimePasswords
  # The failure for a code that didn't verify. A locked code gets its own
  # message, so the user knows to request a new one instead of retrying.
  module Rejection
    private

    def code_rejected(one_time_password)
      key = one_time_password&.locked? ? "errors.code_locked" : "errors.invalid_code"
      failure(:invalid_code, I18n.t(key))
    end
  end
end
