module Users
  class GenerateToken < BaseInteractor
    delegate :user, to: :context

    def call
      context.token = generate_token
    end

    private

    def generate_token
      JWT.encode(payload, secret_key, 'HS256')
    end

    def payload
      { sub: user.id, exp: 30.days.from_now.to_i }
    end

    def secret_key
      Rails.application.secret_key_base
    end
  end
end
