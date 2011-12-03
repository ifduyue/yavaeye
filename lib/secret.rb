# encoding: UTF-8

# to generate secret: run rake secret
# NOTE this is not a complete module, it needs config/secret.rb
module Secret
  def init
    f = File.dirname(__FILE__) + '/../config/secret.rb'
    f = File.expand_path f
    if !(File.exist? f)
      puts "First time running, generating #{f} ..."
      File.open f, 'w' do |f|
        f.puts [
          "# Generated by lib/secret.rb. If you want new secret keys, remove this file.",
          "module Secret",
          'KEY='.<<(rand_string(256).inspect),
          'IV='.<<(rand_string(256).inspect),
          'SALT='.<<(rand_string(8).inspect),
          'SESSION_KEY='.<<(rand_string(256).inspect),
          'end'
        ]
      end
    end
    require f
  end

  def encrypt s
    c = OpenSSL::Cipher.new 'aes-256-cbc'
    c.encrypt
    c.key = KEY
    c.iv = IV
    res = c.update s
    res.<< c.update SALT
    res << c.final
    Base64.strict_encode64 res
  end

  def decrypt s
    return nil if s.blank?
    s = Base64.strict_decode64 s rescue ''
    return nil if s.size > 512 or s.size % 16 != 0
    c = OpenSSL::Cipher.new 'aes-256-cbc'
    c.decrypt
    c.key = KEY
    c.iv = IV
    res = c.update s
    res << c.final
    if res.end_with?(SALT)
      res[0...(- SALT.size)]
    end
  rescue OpenSSL::Cipher::CipherError
    nil
  end

  def session_secret
    SESSION_KEY
  end

  def admin_password= p
    h = doc
    h['admin_password'] = BCrypt::Password.create(p).to_s
    update h
  end

  def first_time
    !doc['admin_password']
  end

  def validate_admin_password p
    BCrypt::Password.new(doc['admin_password']) == p
  end

private

  def rand_string l
    rand(36 ** l).to_s(36).ljust l, '*'
  end

  def doc
    if h = Mongoid.database['secret'].find_one
      h
    else
      Mongoid.database['secret'].save({})
      doc
    end
  end

  def update h
    Mongoid.database['secret'].save h
  end

  extend self
end

