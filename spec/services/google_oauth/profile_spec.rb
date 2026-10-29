require "rails_helper"

RSpec.describe GoogleOauth::Profile do
  describe ".people_details" do
    def details(person) = described_class.people_details(person.deep_stringify_keys)

    it "takes the primary phone in E.164 and a full birthday" do
      person = { phoneNumbers: [{ metadata: {}, canonicalForm: "+12025550199" },
                                { metadata: { primary: true }, canonicalForm: "+12015550123" }],
                 birthdays: [{ metadata: { primary: true }, date: { year: 1990, month: 4, day: 15 } }] }

      expect(details(person)).to eq(phone: "+12015550123", birthday: Date.new(1990, 4, 15))
    end

    it "falls back to the number as typed when Google gives no canonical form" do
      expect(details(phoneNumbers: [{ value: "+92 300 1234567" }])).to eq(phone: "+92 300 1234567")
    end

    it "skips a birthday shared without its year" do
      person = { birthdays: [{ metadata: { primary: true }, date: { month: 4, day: 15 } },
                             { metadata: {}, date: { year: 1990, month: 4, day: 15 } }] }

      expect(details(person)).to eq(birthday: Date.new(1990, 4, 15))
    end

    it "is empty when nothing was shared" do
      expect(details({})).to eq({})
    end
  end
end
