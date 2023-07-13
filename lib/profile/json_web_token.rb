require 'jwt'

module Profile
  class JsonWebToken
    def self.enabled?
      Config.shared_secret.present?
    end

    def self.encode(payload, expiration = nil)
      payload = payload.dup
      payload['iat'] = Time.now.to_i
      JWT.encode(
        payload,
        Config.shared_secret,
        'HS256'
      )
    end

    def self.decode(token, options={})
      JWT.decode(
        token,
        Config.shared_secret,
        true,
        { algorithm: 'HS256' }.merge(options)
      ).first
    end
  end
end
