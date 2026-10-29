module GoogleOauth
  # Everything Google tells us about who signed in. `uid` (OpenID `sub`) never
  # changes for a Google account; the email can, so accounts are linked by uid
  # once known. `phone` (E.164) and `birthday` (a Date) come from the People
  # API and are nil when not shared; `locale` is the language Google reports.
  Profile = Data.define(:uid, :email, :email_verified, :first_name, :last_name, :picture_url, :locale,
                        :phone, :birthday) do
    def self.from_userinfo(info)
      new(uid: info.fetch("sub"), email: info["email"], email_verified: info["email_verified"] == true,
          first_name: info["given_name"], last_name: info["family_name"], picture_url: info["picture"],
          locale: info["locale"], phone: nil, birthday: nil)
    end

    # The primary phone number and a complete birthday from a People API person.
    def self.people_details(person)
      full_birthdays = person["birthdays"]&.select { full_date?(it["date"]) }
      birthday_date = primary(full_birthdays)&.dig("date")
      { phone: phone(primary(person["phoneNumbers"])), birthday: birthday(birthday_date) }.compact
    end

    # canonicalForm is E.164; Google omits it when it can't tell the country, and
    # then the number as typed is passed on (the account keeps it only if valid).
    def self.phone(entry) = entry && (entry["canonicalForm"].presence || entry["value"].presence)

    def self.primary(entries)
      Array(entries).find { it.dig("metadata", "primary") } || Array(entries).first
    end

    # Google can share a birthday without its year; only a full date is a birthday.
    def self.full_date?(date) = date.is_a?(Hash) && date.values_at("year", "month", "day").all?(Integer)

    def self.birthday(date)
      Date.new(date["year"], date["month"], date["day"]) if date
    rescue Date::Error
      nil
    end

    private_class_method :phone, :primary, :full_date?, :birthday
  end
end
