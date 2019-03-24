# Lockbox

:lock: File encryption for Ruby and Rails

- Supports Active Storage and CarrierWave
- Uses AES-GCM by default for [authenticated encryption](https://tonyarcieri.com/all-the-crypto-code-youve-ever-written-is-probably-broken)
- Makes key rotation easy

Check out [this post](https://ankane.org/sensitive-data-rails) for more info on securing sensitive data with Rails

[![Build Status](https://travis-ci.org/ankane/lockbox.svg?branch=master)](https://travis-ci.org/ankane/lockbox)

## Installation

Add this line to your application’s Gemfile:

```ruby
gem 'lockbox'
```

## Key Generation

Generate an encryption key

```ruby
SecureRandom.hex(32)
```

Store the key with your other secrets. This is typically Rails credentials or an environment variable ([dotenv](https://github.com/bkeepers/dotenv) is great for this). Be sure to use different keys in development and production. Keys don’t need to be hex-encoded, but it’s often easier to store them this way.

Alternatively, you can use a [key management service](#key-management) to manage your keys.

## Files

Create a box

```ruby
box = Lockbox.new(key: key)
```

Encrypt

```ruby
ciphertext = box.encrypt(File.binread("license.jpg"))
```

Decrypt

```ruby
box.decrypt(ciphertext)
```

## Active Storage

Add to your model:

```ruby
class User < ApplicationRecord
  has_one_attached :license
  attached_encrypted :license, key: key
end
```

Works with multiple attachments as well.

```ruby
class User < ApplicationRecord
  has_many_attached :documents
  attached_encrypted :documents, key: key
end
```

There are a few limitations to be aware of:

- Metadata like image width and height are not extracted when encrypted
- Direct uploads cannot be encrypted

## CarrierWave

Add to your uploader:

```ruby
class LicenseUploader < CarrierWave::Uploader::Base
  encrypt key: key
end
```

Encryption is applied to all versions after processing.

## Serving Files

To serve encrypted files, use a controller action.

```ruby
def license
  send_data @user.license.download, type: @user.license.content_type
end
```

Use `read` instead of `download` for CarrierWave.

## Key Rotation

To make key rotation easy, you can pass previous versions of keys that can decrypt.

```ruby
Lockbox.new(key: key, previous_versions: [{key: previous_key}])
```

For Active Storage use:

```ruby
class User < ApplicationRecord
  attached_encrypted :license, key: key, previous_versions: [{key: previous_key}]
end
```

To rotate existing files, use:

```ruby
user.license.rotate_encryption!
```

For CarrierWave, use:

```ruby
class LicenseUploader < CarrierWave::Uploader::Base
  encrypt key: key, previous_versions: [{key: previous_key}]
end
```

To rotate existing files, use:

```ruby
user.license.rotate_encryption!
```

## Algorithms

### AES-GCM

The default algorithm is AES-GCM with a 256-bit key. Rotate the key every 2 billion files to minimize the chance of a [nonce collision](https://www.cryptologie.net/article/402/is-symmetric-security-solved/), which will leak the key.

### XChaCha20

[Install Libsodium](https://github.com/crypto-rb/rbnacl/wiki/Installing-libsodium) >= 1.0.12 and add [rbnacl](https://github.com/crypto-rb/rbnacl) to your application’s Gemfile:

```ruby
gem 'rbnacl'
```

Then pass the `algorithm` option:

```ruby
# files
box = Lockbox.new(key: key, algorithm: "xchacha20")

# Active Storage
class User < ApplicationRecord
  attached_encrypted :license, key: key, algorithm: "xchacha20"
end

# CarrierWave
class LicenseUploader < CarrierWave::Uploader::Base
  encrypt key: key, algorithm: "xchacha20"
end
```

Make it the default with:

```ruby
Lockbox.default_options = {algorithm: "xchacha20"}
```

You can also pass an algorithm to `previous_versions` for key rotation.

## Hybrid Cryptography

[Hybrid cryptography](https://en.wikipedia.org/wiki/Hybrid_cryptosystem) allows servers to encrypt data without being able to decrypt it.

[Install Libsodium](https://github.com/crypto-rb/rbnacl/wiki/Installing-libsodium) and add [rbnacl](https://github.com/crypto-rb/rbnacl) to your application’s Gemfile:

```ruby
gem 'rbnacl'
```

Generate a key pair with:

```ruby
Lockbox.generate_key_pair
```

Store the keys with your other secrets. Then use:

```ruby
# files
box = Lockbox.new(algorithm: "hybrid", encryption_key: encryption_key, decryption_key: decryption_key)

# Active Storage
class User < ApplicationRecord
  attached_encrypted :license, algorithm: "hybrid", encryption_key: encryption_key, decryption_key: decryption_key
end

# CarrierWave
class LicenseUploader < CarrierWave::Uploader::Base
  encrypt algorithm: "hybrid", encryption_key: encryption_key, decryption_key: decryption_key
end
```

Make sure `decryption_key` is `nil` on servers that shouldn’t decrypt.

This uses X25519 for key exchange and XSalsa20-Poly1305 for encryption.

## Key Management

You can use a key management service to manage your keys with [KMS Encrypted](https://github.com/ankane/kms_encrypted).

For Active Storage, use:

```ruby
class User < ApplicationRecord
  attached_encrypted :license, key: :kms_key
end
```

For CarrierWave, use:

```ruby
class LicenseUploader < CarrierWave::Uploader::Base
  encrypt key: -> { model.kms_key }
end
```

**Note:** KMS Encrypted’s key rotation does not know to rotate encrypted files, so avoid calling `record.rotate_kms_key!` on models with file uploads for now.

## Compatibility

It’s easy to read encrypted files in another language if needed.

Here are [some examples](docs/Compatibility.md).

The format for AES-GCM is:

- nonce (IV) - 12 bytes
- ciphertext - variable length
- authentication tag - 16 bytes

For XChaCha20, use the appropriate [Libsodium library](https://libsodium.gitbook.io/doc/bindings_for_other_languages).

## Database Fields

Lockbox can also be used with [attr_encrypted](https://github.com/attr-encrypted/attr_encrypted) for database fields. This gives you:

1. Easy key rotation
2. XChaCha20
3. Hybrid cryptography
4. No need for separate IV columns

Add to your Gemfile:

```ruby
gem 'attr_encrypted'
```

Create a migration to add a new column for the encrypted data. We don’t need a separate IV column, as this will be included in the encrypted data.

```ruby
class AddEncryptedPhoneToUsers < ActiveRecord::Migration[5.2]
  def change
    add_column :users, :encrypted_phone, :string
  end
end
```

Add to your model:

```ruby
class User < ApplicationRecord
  attr_encrypted :phone, encryptor: Lockbox::Encryptor, key: key, algorithm: "xchacha20", previous_versions: [{key: previous_key}], iv: ""
end
```

All Lockbox options are supported. Set `iv` to empty string as Lockbox take care of the IV.

For hybrid cryptography, use:

```ruby
class User < ApplicationRecord
  attr_encrypted :phone, encryptor: Lockbox::Encryptor, algorithm: "hybrid", encryption_key: encryption_key, decryption_key: decryption_key, iv: ""
end
```

## Reference

Pass associated data to encryption and decryption

```ruby
box.encrypt(message, associated_data: "bingo")
box.decrypt(ciphertext, associated_data: "bingo")
```

## History

View the [changelog](https://github.com/ankane/lockbox/blob/master/CHANGELOG.md)

## Contributing

Everyone is encouraged to help improve this project. Here are a few ways you can help:

- [Report bugs](https://github.com/ankane/lockbox/issues)
- Fix bugs and [submit pull requests](https://github.com/ankane/lockbox/pulls)
- Write, clarify, or fix documentation
- Suggest or add new features
