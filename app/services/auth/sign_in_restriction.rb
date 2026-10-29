module Auth
  module SignInRestriction
    private

    def sign_in_blocked(user)
      failure(:access_revoked, I18n.t("errors.sign_in_blocked.#{user.sign_in_blocked_reason}"))
    end
  end
end
