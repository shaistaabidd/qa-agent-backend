# Signed, short-lived tokens for the GitHub round trips. `state` binds the
# install/sign-in redirect to the project and the user who started it, so a
# callback can't be replayed against a different project or by a different
# user. The `choice` token carries the installations GitHub confirmed that
# user can access, so they can pick one without a second single-use code.
class GitHubInstallState
  PURPOSE = :github_install
  TTL = 30.minutes
  CHOICE_PURPOSE = :github_install_choice
  CHOICE_TTL = 10.minutes

  def self.generate(project:, user:)
    verifier.generate({ 'project_id' => project.id, 'user_id' => user.id }, purpose: PURPOSE, expires_in: TTL)
  end

  # => { 'project_id' => .., 'user_id' => .. } or nil if tampered/expired.
  def self.verify(state)
    verifier.verified(state.to_s, purpose: PURPOSE)
  end

  def self.generate_choice(project_id:, user_id:, installation_ids:)
    payload = { 'project_id' => project_id, 'user_id' => user_id, 'installation_ids' => installation_ids }
    verifier.generate(payload, purpose: CHOICE_PURPOSE, expires_in: CHOICE_TTL)
  end

  # => { 'project_id', 'user_id', 'installation_ids' } or nil if tampered/expired.
  def self.verify_choice(token)
    verifier.verified(token.to_s, purpose: CHOICE_PURPOSE)
  end

  def self.verifier
    Rails.application.message_verifier(PURPOSE)
  end
end
