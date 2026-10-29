module Invitations
  # Invites a batch of people. Addresses that fail validation are skipped and
  # reported back; every valid address is saved in one transaction and emailed.
  # If no address is valid the batch fails with the first address's errors.
  class SendInvitations < ApplicationService
    MAX_EMAILS = 20

    Rejection = Data.define(:email, :message)
    Outcome = Data.define(:invited, :rejected)

    def initialize(emails:, role:, invited_by:)
      @emails = emails.map { User.normalize_value_for(:email, it) }.uniq
      @role = role
      @invited_by = invited_by
    end

    def call
      return failure(:validation_failed, batch_size_message) unless batch_size_allowed?
      return failure(:validation_failed, taken_emails_message) if taken_emails.any?

      valid_invitees, rejected_invitees = build_invitees.partition(&:valid?)
      return failure(:validation_failed, record: rejected_invitees.first) if valid_invitees.empty?

      save_and_notify(valid_invitees)
      success(outcome(valid_invitees, rejected_invitees))
    end

    private

    def save_and_notify(invitees)
      User.transaction { invitees.each(&:save!) }
      invitees.each { InvitationMailer.with(user: it).invitation.deliver_later }
    end

    def batch_size_allowed? = @emails.size.between?(1, MAX_EMAILS)
    def batch_size_message = I18n.t("errors.invitation_count", count: MAX_EMAILS)
    def taken_emails_message = I18n.t("errors.emails_taken", emails: taken_emails.to_sentence)

    def taken_emails
      @taken_emails ||= User.where(email: @emails).pluck(:email)
    end

    def outcome(invited, rejected)
      Outcome.new(invited:, rejected: rejected.map { rejection_for(it) })
    end

    def build_invitees = @emails.map { build_invitee(it) }

    def rejection_for(invitee)
      Rejection.new(email: invitee.email, message: invitee.errors.full_messages.to_sentence)
    end

    def build_invitee(email)
      User.new(email:, role: @role, invited_by: @invited_by, invitation_sent_at: Time.current)
    end
  end
end
